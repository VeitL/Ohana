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
    @Query(sort: \OasisUpgradeCoconut.level) private var upgradeCoconuts: [OasisUpgradeCoconut]
    @Query(sort: \OasisElectronicPet.obtainedAt) private var electronicPets: [OasisElectronicPet]
    @Query(sort: \OasisCritterFragmentBalance.updatedAt) private var critterFragments: [OasisCritterFragmentBalance]

    @State private var treeScale: CGFloat   = 1.0
    @State private var treeGlow: CGFloat    = 0.4
    @State private var showAchievements     = false
    @State private var showingCoconutLog    = false
    @State private var showCoconutShop      = false
    @State private var coconutShopInitialCategory: ShopItem.ShopCategory = .effect
    @State private var showGacha            = false
    @State private var showInventory        = false
    @State private var showCoconutRules     = false
    @State private var showCheckInCalendar  = false
    @State private var showCheckInSheet     = false
    @State private var showCritterNest      = false
    @State private var showCritterCodex     = false
    @State private var energyParticles: [EnergyParticle] = []
    // 模块六：打卡日历
    @State private var checkedInDates: Set<String> = []   // "yyyy-MM-dd" 格式
    @State private var makeupPackCount: Int = 0            // 补签包数量
    @State private var showMakeupConfirm: String? = nil    // 待确认补签的日期
    @State private var makeupDates: Set<String> = []       // 补签过的日期集合
    @State private var lastClaimedMilestone: Int = 0
    @AppStorage("currentActiveHumanId") private var currentActiveHumanId = ""
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var workloadPolicy = AppWorkloadPolicy.shared

    private var isMaterial: Bool { false }
    private var matBg:      Color { colorScheme == .light ? Color(hex: "F5F5F7") : Color(hex: "0A0A0C") }
    private var matSurface: Color { colorScheme == .light ? .white : Color(hex: "1C1C1E") }
    private var matAccent:  Color { Color(hex: "FF5A00") }
    @State private var lastLevel: TreeLevel = .lv1
    @State private var isInjecting: Bool = false
    @State private var injectionPulseToken = 0
    @State private var levelUpPulse         = false
    @State private var levelUpBadgeVisible  = false
    @State private var harvestBubbleBounce  = false
    @State private var justHarvested        = false
    @State private var openedUpgradeReward: OasisOpenedUpgradeReward?
    @State private var openingUpgradeCoconutId: UUID?
    @State private var critterActionPulseId: UUID?
    @State private var lastCritterInteractionOutcome: OasisCritterInteractionOutcome?
    @State private var rescuingCritterId: UUID?
    // 任务7：环境光晕 + 采摘飞出
    @State private var glowBreathing: Bool  = false
    @State private var flyCoconut: Bool     = false
    @State private var flyOpacity: Double   = 0
    @State private var harvestedCoconutIndices: Set<Int> = []
    @State private var isVisible = false
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

    private let treeMgr = OasisTreeManager.shared
    private var l: L10n { L10n(appLanguage) }

    private var pendingUpgradeCoconuts: [OasisUpgradeCoconut] {
        upgradeCoconuts
            .filter { !$0.isOpened }
            .sorted { $0.level < $1.level }
    }

    private var activeHuman: Human? {
        humans.first { $0.id.uuidString == currentActiveHumanId }
    }

    private var activeHumanCoconutBalance: Int {
        activeHuman?.coconutBalance ?? QuestManager.shared.coconutCount
    }

    private var shouldRunAmbientMotion: Bool {
        workloadPolicy.shouldAnimate(isVisible: isVisible)
    }

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

    private func oasisToolbarButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(Color.ohanaPrimaryText)
                .frame(width: 44, height: 44)
                .background(Color.ohanaControlFill, in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(Color.ohanaGlassStroke.opacity(0.72), lineWidth: 0.6)
                }
        }
        .buttonStyle(ScaleButtonStyle())
    }

    var body: some View {
        ZStack {
            OhanaAppBackground()
                .ignoresSafeArea()

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

                    // ── Bento 功能区（紧凑小卡）
                    oasisBentoGrid
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        .padding(.bottom, 140)
                }
            }

            if !hideToolbar {
                oasisFixedToolbar
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .zIndex(120)
            }
        }
        .fullScreenCover(isPresented: $showingCoconutLog) { CoconutLogView() }
        .sheet(isPresented: $showCoconutRules) { CoconutRulesSheet() }
        .sheet(isPresented: $showAchievements) {
            if let pet = pets.first {
                AchievementWallView(pet: pet, allPets: pets)
                    .presentationDetents([.large]) // ui-v4: allow long achievement overview
            }
        }
        .sheet(isPresented: $showInventory) {
            InventoryView()
                .presentationDetents([.large]) // ui-v4: allow long inventory overview
        }
        .sheet(isPresented: $showCoconutShop) {
            CoconutShopView(initialCategory: coconutShopInitialCategory)
                .presentationDetents([.large]) // ui-v4: allow long shop overview
        }
        .overlay {
            if showGacha {
                GachaView(drawsBackground: false) {
                    withAnimation(GoMotion.page) {
                        showGacha = false
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(20)
            }
        }
        .sheet(isPresented: $showCheckInSheet) {
            DailyStreakDetailView(pets: pets, onClose: { showCheckInSheet = false })
                .presentationDetents([.large]) // ui-v4: allow long streak overview
        }
        .sheet(isPresented: $showCritterCodex) {
            OasisCritterCodexView(mode: .codex)
                .presentationDetents([.large]) // ui-v4: allow long critter codex overview
        }
        .sheet(isPresented: $showCritterNest) {
            OasisCritterCodexView(mode: .nest)
                .presentationDetents([.large]) // ui-v4: allow long critter nest overview
        }
        .onAppear {
            isVisible = true
            treeMgr.refreshEnergy(modelContext: modelContext, pets: pets, humans: humans, plants: plants)
            refreshFeaturedCritterLifecycle()
            lastLevel = treeMgr.treeLevel
            startAmbientMotionIfNeeded()
            loadCheckInData()
            triggerTodayCheckIn()
        }
        .onDisappear {
            isVisible = false
            stopAmbientMotion()
        }
        .onChange(of: shouldRunAmbientMotion) { _, shouldAnimate in
            if shouldAnimate {
                startAmbientMotionIfNeeded()
            } else {
                stopAmbientMotion()
            }
        }
        .onChange(of: currentActiveHumanId) { _, _ in
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
        .onChange(of: electronicPets.count) { _, _ in refreshFeaturedCritterLifecycle() }
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

    private var oasisFixedToolbar: some View {
        HStack(spacing: 8) {
            oasisToolbarButton(systemName: "xmark") {
                dismiss()
            }
            .accessibilityLabel("关闭")

            Spacer()

            oasisToolbarButton(systemName: "info.circle") {
                showCoconutRules = true
            }
            .accessibilityLabel("椰子规则")
            oasisToolbarButton(systemName: "shippingbox.fill") {
                showInventory = true
            }
            .accessibilityLabel("库存")
        }
    }

    private var oasisHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("OASIS · 绿洲")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .kerning(1.2)
                    .foregroundStyle(Color.ohanaSecondaryText)
                Text("生命之树")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
            }
            Spacer()
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showingCoconutLog = true
            } label: {
                HStack(spacing: 5) {
                    Text("🥥")
                        .font(.system(size: 15))
                    Text("\(activeHumanCoconutBalance)")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryActionText)
                        .contentTransition(.numericText())
                        .ohanaNumericMotion(activeHumanCoconutBalance)
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(Color.ohanaPrimaryActionText.opacity(0.72))
                }
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(Color.goPrimary, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel("椰子资产 \(activeHumanCoconutBalance)")
            .accessibilityHint("打开椰子历史")
        }
    }

    // MARK: - Life Tree Stage

    private var treeSceneCard: some View {
        let stageShape = RoundedRectangle(cornerRadius: 34, style: .continuous)
        return ZStack {
            stageBackground(shape: stageShape)

            stageStars

            Circle()
                .fill(Color.goYellow)
                .frame(width: 26, height: 26)
                .shadow(color: Color.goYellow.opacity(0.68), radius: 14, x: 0, y: 0) // ui-v4: allow Oasis stage celestial glow
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 24)
                .padding(.trailing, 28)

            stageIslandBase

            stageTreeGlow

            treeEnergyBeam

            VStack(spacing: 0) {
                stageTopHUD
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                Spacer(minLength: 0)

                ZStack(alignment: .bottom) {
                    BeautifulCoconutTree(
                        level: treeMgr.treeLevel.rawValue,
                        isInjecting: isInjecting,
                        growthProgress: treeMgr.progressToNextLevel,
                        injectionPulseToken: injectionPulseToken,
                        pendingUpgradeCoconutCount: pendingUpgradeCoconuts.count,
                        allowsAmbientMotion: shouldRunAmbientMotion,
                        harvestedCoconuts: harvestedCoconutIndices,
                        onHarvest: { harvestTreeCoconut($0) }
                    )
                    .shadow(color: Color.goPrimary.opacity(glowBreathing ? 0.42 : 0.16), radius: glowBreathing ? 22 : 10, x: 0, y: 0) // ui-v4: allow Oasis tree focus glow
                    .scaleEffect(levelUpPulse ? 1.18 : treeScale)
                    .animation(GoMotion.fab, value: levelUpPulse)
                    .animation(GoMotion.hero, value: treeScale)
                    .frame(height: 300)
                    .padding(.bottom, 16)

                    if treeMgr.canHarvestToday && !justHarvested {
                        stageHarvestButton
                            .padding(.bottom, 2)
                            .transition(.scale(scale: 0.94).combined(with: .opacity))
                    }

                    treeCritterEntryButton
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                        .padding(.trailing, 26)
                        .padding(.bottom, 140)
                        .zIndex(4)
                }

                stageUpgradeCoconutDock
                    .padding(.horizontal, 18)
                    .padding(.bottom, 10)

                stageEnergyRail
                    .padding(.horizontal, 18)
                    .padding(.bottom, 12)

                stageInjectButton
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)
            }

            if let reward = openedUpgradeReward {
                stageOpenedRewardCard(reward)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .padding(.horizontal, 22)
                    .transition(.scale(scale: 0.94).combined(with: .opacity))
            }

            if flyOpacity > 0 {
                Text("🥥")
                    .font(.system(size: 28))
                    .offset(y: flyCoconut ? -220 : -60)
                    .opacity(flyOpacity)
                    .allowsHitTesting(false)
            }

            if levelUpBadgeVisible {
                stageLevelUpBadge
            }
        }
        .frame(height: 540)
        .clipShape(stageShape)
        .overlay(stageShape.strokeBorder(Color.goPrimary.opacity(0.22), lineWidth: 1))
        .contentShape(stageShape)
        .onAppear {
            justHarvested = !treeMgr.canHarvestToday
            updateGlowMotion()
        }
        .onChange(of: treeMgr.treeLevel) { oldLevel, newLevel in
            justHarvested = !treeMgr.canHarvestToday
            if newLevel.rawValue > oldLevel.rawValue {
                triggerLevelUpFeedback()
            }
        }
    }

    private func stageBackground(shape: RoundedRectangle) -> some View {
        shape
            .fill(
                LinearGradient(
                    colors: colorScheme == .light
                        ? [Color(hex: "D9E8FA"), Color(hex: "BFD1EA"), Color(hex: "8DA8D4")]
                        : [Color(hex: "081338"), Color(hex: "051027"), Color(hex: "020617")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                shape
                    .fill(
                        RadialGradient(
                            colors: [treeMgr.treeLevel.glowColor.opacity(colorScheme == .light ? 0.22 : 0.32), .clear],
                            center: .center,
                            startRadius: 40,
                            endRadius: 300
                        )
                    )
            }
    }

    private var stageStars: some View {
        ZStack {
            ForEach(0..<24, id: \.self) { i in
                let size = CGFloat([1.5, 2.0, 2.5, 1.8][i % 4])
                Circle()
                    .fill(Color.ohanaPrimaryText.opacity(Double([0.28, 0.44, 0.24, 0.5][i % 4])))
                    .frame(width: size, height: size)
                    .offset(x: starPositions[i].0, y: starPositions[i].1)
            }
        }
        .opacity(colorScheme == .light ? 0.45 : 1)
    }

    private var stageIslandBase: some View {
        ZStack(alignment: .bottom) {
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: colorScheme == .light
                            ? [Color(hex: "D4B989"), Color(hex: "B58B55")]
                            : [Color(hex: "E2A545"), Color(hex: "9A5B22")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 304, height: 56)
                .blur(radius: 0.2)

            Ellipse()
                .fill(Color.black.opacity(colorScheme == .light ? 0.12 : 0.26)) // ui-v4: allow grounded island stage shadow
                .frame(width: 250, height: 18)
                .offset(y: 11)
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 110)
        .allowsHitTesting(false)
    }

    private var stageTreeGlow: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [treeMgr.treeLevel.glowColor.opacity(glowBreathing ? 0.30 : 0.10), .clear],
                        center: .center,
                        startRadius: 20,
                        endRadius: 190
                    )
                )
                .frame(width: 340, height: 340)
                .scaleEffect(glowBreathing ? 1.08 : 0.94)
                .animation(
                    shouldRunAmbientMotion
                    ? .easeInOut(duration: 2.4).repeatForever(autoreverses: true) // runtime-guardrail: allow AppWorkloadPolicy-gated stage glow
                    : nil,
                    value: glowBreathing
                )

            Circle()
                .stroke(Color.goPrimary.opacity(glowBreathing ? 0.18 : 0.05), lineWidth: 2)
                .frame(width: 250, height: 250)
                .blur(radius: glowBreathing ? 7 : 2)
                .animation(
                    shouldRunAmbientMotion
                    ? .easeInOut(duration: 2.4).repeatForever(autoreverses: true) // runtime-guardrail: allow AppWorkloadPolicy-gated stage ring
                    : nil,
                    value: glowBreathing
                )
        }
        .offset(y: -32)
        .allowsHitTesting(false)
    }

    private var treeEnergyBeam: some View {
        VStack(spacing: 0) {
            Spacer()
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color.goPrimary.opacity(0), Color.goPrimary.opacity(0.85), Color.goTeal.opacity(0)],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(width: isInjecting ? 9 : 2, height: isInjecting ? 220 : 52)
                .blur(radius: isInjecting ? 5 : 10)
                .opacity(isInjecting ? 0.9 : 0)
                .offset(y: isInjecting ? -138 : -18)
                .animation(GoMotion.feedback, value: injectionPulseToken)
        }
        .allowsHitTesting(false)
    }

    private var stageTopHUD: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Lv.\(treeMgr.treeLevel.rawValue)")
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(treeMgr.treeLevel.displayName)
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaPrimaryActionText.opacity(0.72))
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color.goPrimary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            Spacer(minLength: 4)
        }
    }

    private var treeCritterEntryButton: some View {
        let critter = featuredCritter
        let catalogId = critter?.catalogId ?? nextCritterTargetCatalogId
        let snapshot = critter.map { OasisUpgradeRewardService.lifecycleSnapshot(for: $0, context: modelContext) }
        let tint = snapshot.map { critterLifecycleTint(for: $0.state) } ?? Color.goPrimary
        let statusIcon = snapshot.map { critterLifecycleIcon(for: $0.state) } ?? "lock.fill"
        let isLocked = critter == nil

        return Button {
            openCritterEntry()
        } label: {
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.ohanaControlFill)
                    .frame(width: 66, height: 66)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(tint.opacity(isLocked ? 0.28 : 0.62), lineWidth: isLocked ? 1 : 1.6)
                    )

                OasisCritterIllustration(catalogId: catalogId, locked: isLocked, size: 54, critter: critter)
                    .offset(y: -2)

                Image(systemName: statusIcon)
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(snapshot?.state == .critical ? Color.arkInk : Color.ohanaPrimaryActionText)
                    .frame(width: 22, height: 22)
                    .background(tint, in: Circle())
                    .overlay(Circle().strokeBorder(Color.ohanaCardSurface.opacity(0.84), lineWidth: 1))
                    .offset(x: 3, y: 3)
            }
            .overlay(alignment: .bottom) {
                Text(critter?.displayName(l) ?? l.tr(zh: "Lv.5", en: "Lv.5", de: "Lv.5"))
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.ohanaCardSurface.opacity(0.84), in: Capsule())
                    .offset(y: 13)
            }
            .frame(width: 74, height: 82)
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(critter == nil ? nextCritterGoalText : l.tr(zh: "电子宠物小窝", en: "Critter nest", de: "Critter-Nest"))
    }

    private var stageUpgradeCoconutDock: some View {
        HStack(spacing: 10) {
            if let reward = openedUpgradeReward {
                HStack(spacing: 6) {
                    Text(reward.emoji)
                    Text(reward.title(l))
                        .lineLimit(1)
                }
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(Color.ohanaControlFill, in: Capsule())
            }

            if pendingUpgradeCoconuts.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                    Text(nextStageHint)
                        .lineLimit(1)
                }
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
            } else {
                ForEach(Array(pendingUpgradeCoconuts.prefix(3)), id: \.id) { coconut in
                    stageUpgradeCoconutButton(coconut)
                }
                if pendingUpgradeCoconuts.count > 3 {
                    Text("+\(pendingUpgradeCoconuts.count - 3)")
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(width: 42, height: 42)
                        .background(Color.ohanaControlFill, in: Circle())
                }
            }

            Spacer(minLength: 0)
        }
        .frame(minHeight: 44)
    }

    private func stageUpgradeCoconutButton(_ coconut: OasisUpgradeCoconut) -> some View {
        let isOpening = openingUpgradeCoconutId == coconut.id
        let isMilestone = coconut.rewardKind == .electronicPet
        return Button {
            openUpgradeCoconut(coconut)
        } label: {
            ZStack(alignment: .bottomTrailing) {
                Text("🥥")
                    .font(.system(size: 28))
                    .rotationEffect(.degrees(isOpening ? -12 : 0))
                    .scaleEffect(isOpening ? 1.14 : 1)
                    .frame(width: 48, height: 48)
                    .background(isMilestone ? Color.goPrimary.opacity(0.18) : Color.ohanaControlFill, in: Circle())
                Image(systemName: "hammer.fill")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .frame(width: 19, height: 19)
                    .background(Color.goPrimary, in: Circle())
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("\(coconut.title(l)) \(l.tr(zh: "敲开", en: "Open", de: "Öffnen"))")
    }

    private var stageEnergyRail: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Text(treeMgr.treeLevel == .lv10 ? l.tr(zh: "满级", en: "Max", de: "Max") : "\(treeMgr.totalEnergy)/\(treeMgr.nextLevelThreshold)")
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Spacer()
                Text(treeMgr.passiveIncomeAmount > 0 ? "+\(treeMgr.passiveIncomeAmount)🥥/d" : "Lv.5 🥥")
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(Color.goPrimary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.ohanaControlFill)
                    Capsule()
                        .fill(LinearGradient(colors: [Color.goPrimary, Color.goTeal], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(8, geo.size.width * treeMgr.progressToNextLevel))
                        .contentTransition(.numericText())
                }
                .frame(height: 8)
                .animation(GoMotion.page, value: treeMgr.progressToNextLevel)
            }
            .frame(height: 8)
        }
    }

    private var stageInjectButton: some View {
        let canInject = OasisCritterEconomyService.canSpendCurrentHumanCoconuts(10, context: modelContext) && !isInjecting
        return Button {
            injectTreeEnergy()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 13, weight: .black))
                Text(l.tr(zh: "注入 +10", en: "Infuse +10", de: "+10 einspeisen"))
                    .font(OhanaFont.callout(.black))
                Text("-10🥥")
                    .font(OhanaFont.caption(.black))
                    .opacity(0.66)
            }
            .foregroundStyle(canInject ? Color.ohanaPrimaryActionText : Color.ohanaSecondaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(canInject ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!canInject)
        .opacity(canInject ? 1 : 0.55)
    }

    private var stageHarvestButton: some View {
        Button {
            harvestDailyTreeCoconuts()
        } label: {
            HStack(spacing: 6) {
                Text("🥥")
                    .font(.system(size: 17))
                Text("+\(treeMgr.passiveIncomeAmount)")
                    .font(OhanaFont.caption(.black))
                    .monospacedDigit()
            }
            .foregroundStyle(Color.arkInk)
            .padding(.horizontal, 14)
            .frame(height: 38)
            .background(Color.goYellow, in: Capsule())
            .shadow(color: Color.goYellow.opacity(harvestBubbleBounce ? 0.58 : 0.24), radius: harvestBubbleBounce ? 14 : 7, x: 0, y: 5) // ui-v4: allow tappable Oasis harvest reward glow
            .scaleEffect(harvestBubbleBounce ? 1.045 : 1.0)
            .animation(
                shouldRunAmbientMotion
                ? .easeInOut(duration: 0.85).repeatForever(autoreverses: true) // runtime-guardrail: allow AppWorkloadPolicy-gated harvest affordance
                : nil,
                value: harvestBubbleBounce
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .onAppear { updateHarvestBubbleMotion() }
    }

    @ViewBuilder
    private func stageOpenedRewardCard(_ reward: OasisOpenedUpgradeReward) -> some View {
        if reward.isMilestoneCritter,
           let catalogId = reward.critterCatalogId,
           let entry = OasisUpgradeRewardCatalog.critter(id: catalogId) {
            OasisCritterUnlockRewardCard(
                catalogId: catalogId,
                newLabel: l.tr(zh: "新伙伴", en: "NEW", de: "NEU"),
                rarityText: l.tr(zh: entry.rarity.zh, en: entry.rarity.en, de: entry.rarity.de),
                title: entry.name(l),
                detail: reward.detail(l),
                confirmTitle: l.tr(zh: "收下", en: "Keep", de: "Behalten"),
                accent: critterRarityColor(entry.rarity),
                onClose: {
                    withAnimation(GoMotion.feedback) {
                        openedUpgradeReward = nil
                    }
                }
            )
        } else {
            HStack(spacing: 12) {
                Text(reward.emoji)
                    .font(.system(size: 34))
                    .frame(width: 54, height: 54)
                    .background(Color.goYellow.opacity(0.18), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(reward.title(l))
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                    Text(reward.detail(l))
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Button {
                    withAnimation(GoMotion.feedback) {
                        openedUpgradeReward = nil
                    }
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Color.ohanaPrimaryActionText)
                        .frame(width: 38, height: 38)
                        .background(Color.goPrimary, in: Circle())
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(12)
            .background(Color.ohanaCardSurface.opacity(0.94), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.goPrimary.opacity(0.12), lineWidth: 1)
            )
        }
    }

    private var stageLevelUpBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .black))
            Text("Lv.\(treeMgr.treeLevel.rawValue)")
                .font(OhanaFont.caption(.black))
                .monospacedDigit()
        }
        .foregroundStyle(Color.ohanaPrimaryActionText)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.goPrimary, in: Capsule())
        .shadow(color: Color.goPrimary.opacity(0.55), radius: 16, x: 0, y: 6) // ui-v4: allow transient level-up celebration
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 60)
        .transition(.scale.combined(with: .opacity))
        .allowsHitTesting(false)
    }

    private var nextStageHint: String {
        if treeMgr.treeLevel == .lv10 {
            return l.tr(zh: "树冠已觉醒", en: "Tree awakened", de: "Baum erwacht")
        }
        return l.tr(zh: "下一颗升级椰子在树上成长", en: "Next upgrade coconut is growing", de: "Nächste Upgrade-Kokosnuss wächst")
    }

    private var nextCritterTargetCatalogId: String {
        treeMgr.treeLevel.rawValue < 5
            ? OasisUpgradeRewardCatalog.firstCritterId
            : OasisUpgradeRewardCatalog.legendaryCritterId
    }

    private func harvestTreeCoconut(_ idx: Int) {
        guard !harvestedCoconutIndices.contains(idx) else { return }
        harvestedCoconutIndices.insert(idx)
        OasisCritterEconomyService.awardCurrentHumanCoconuts(1, emoji: "🥥", title: "摘下椰子 +1🥥", context: modelContext)
        modelContext.safeSave()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        flyCoconut = false
        flyOpacity = 1
        withAnimation(GoMotion.fab.delay(0.05)) {
            flyCoconut = true
        }
        withAnimation(GoMotion.quick.delay(0.6)) {
            flyOpacity = 0
        }
    }

    private func harvestDailyTreeCoconuts() {
        guard treeMgr.canHarvestToday else { return }
        let amount = treeMgr.passiveIncomeAmount
        guard amount > 0 else { return }
        UserDefaults.standard.set(Date(), forKey: OasisTreeManager.passiveIncomeKey)
        OasisCritterEconomyService.awardCurrentHumanCoconuts(amount, emoji: "🌳", title: "生命之树的馈赠 +\(amount)🥥", context: modelContext)
        modelContext.safeSave()
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        withAnimation(GoMotion.feedback) { justHarvested = true }
        spawnEnergyParticles(count: 10)
        flyCoconut = false
        flyOpacity = 1
        withAnimation(GoMotion.fab.delay(0.05)) {
            flyCoconut = true
        }
        withAnimation(GoMotion.quick.delay(0.6)) {
            flyOpacity = 0
        }
    }

    private func openCritterEntry() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        showCritterNest = true
    }

    private func injectTreeEnergy() {
        guard !isInjecting else { return }
        guard OasisCritterEconomyService.canSpendCurrentHumanCoconuts(10, context: modelContext) else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }

        let beforeLevel = treeMgr.treeLevel
        withAnimation(GoMotion.feedback) {
            injectionPulseToken += 1
            isInjecting = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.72) {
            withAnimation(GoMotion.quick) {
                isInjecting = false
            }
        }

        if treeMgr.injectEnergy(cost: 10, modelContext: modelContext) {
            spawnEnergyParticles(count: 12)
            if treeMgr.treeLevel != beforeLevel {
                triggerLevelUpFeedback()
            }
        } else {
            withAnimation(GoMotion.quick) {
                isInjecting = false
            }
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    // MARK: - Electronic Pet Motivation

    private var oasisCritterMotivationCard: some View {
        VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 14) {
                    if let critter = featuredCritter {
                        OasisCritterIllustration(catalogId: critter.catalogId, locked: false, size: 104, critter: critter)
                            .scaleEffect(critterActionPulseId == critter.id ? 1.06 : 1)
                        VStack(alignment: .leading, spacing: 7) {
                            HStack(spacing: 7) {
                                Text(l.tr(zh: "电子宠物小窝", en: "Critter Nest", de: "Critter-Nest"))
                                    .font(.system(size: 18, weight: .black, design: .rounded))
                                    .foregroundStyle(Color.ohanaPrimaryText)
                                Text(l.tr(zh: critter.rarity.zh, en: critter.rarity.en, de: critter.rarity.de))
                                    .font(.system(size: 9, weight: .black, design: .rounded))
                                    .foregroundStyle(Color.ohanaPrimaryActionText)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(critterRarityColor(critter.rarity), in: Capsule())
                            }
                            Text(critter.displayName(l))
                                .font(.system(size: 24, weight: .black, design: .rounded))
                                .foregroundStyle(Color.goPrimary)
                                .contentTransition(.numericText())
                            HStack(spacing: 8) {
                                critterQuickMetric(icon: "fork.knife", value: "\(critter.hunger)")
                                critterQuickMetric(icon: "face.smiling", value: "\(critter.mood)")
                                critterQuickMetric(icon: "cross.case.fill", value: "\(critter.health)")
                                critterQuickMetric(icon: "heart.fill", value: "B\(OasisUpgradeRewardService.bondLevel(for: critter))")
                                critterQuickMetric(icon: "star.fill", value: "\(critter.starLevel)")
                            }
                        }
                    } else {
                        OasisCritterIllustration(catalogId: OasisUpgradeRewardCatalog.firstCritterId, locked: true, size: 104)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(l.tr(zh: "升级生命树，唤醒电子宠物", en: "Level the tree. Wake critters.", de: "Baum leveln. Critter wecken."))
                                .font(.system(size: 19, weight: .black, design: .rounded))
                                .foregroundStyle(Color.ohanaPrimaryText)
                                .lineLimit(2)
                            Text(nextCritterGoalText)
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundStyle(Color.goPrimary)
                            milestoneProgressBar
                        }
                    }

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }

                if featuredCritter == nil {
                    HStack(spacing: 10) {
                        critterMilestonePill(level: 5, catalogId: OasisUpgradeRewardCatalog.firstCritterId)
                        critterMilestonePill(level: 10, catalogId: OasisUpgradeRewardCatalog.legendaryCritterId)
                    }
                } else if let critter = featuredCritter {
                    let snapshot = OasisUpgradeRewardService.lifecycleSnapshot(for: critter, context: modelContext)
                    let wish = OasisUpgradeRewardService.displayDailyWish(for: critter, snapshot: snapshot)
                    let wishCompleted = OasisUpgradeRewardService.isDailyWishCompleted(for: critter, wish: wish, context: modelContext)
                    critterLifeStrip(critter, snapshot: snapshot)
                    critterWishStrip(wish, critter: critter, isCompleted: wishCompleted)
                    if let lastCritterInteractionOutcome, lastCritterInteractionOutcome.success {
                        critterOutcomeStrip(lastCritterInteractionOutcome)
                    }
                    if snapshot.isRescuable {
                        HStack(spacing: 8) {
                            critterNestAction(
                                icon: "cross.case.fill",
                                title: l.tr(zh: "照顾一下", en: "Care now", de: "Pflegen"),
                                cost: l.tr(zh: "免费", en: "Free", de: "Gratis"),
                                enabled: rescuingCritterId != critter.id,
                                highlighted: true
                            ) {
                                rescue(with: critter)
                            }
                        }
                    }
                    HStack(spacing: 8) {
                        critterNestAction(
                            icon: "fork.knife",
                            title: l.tr(zh: "喂养", en: "Feed", de: "Füttern"),
                            cost: critterInteractionCostText(critter, action: .feed),
                            enabled: OasisUpgradeRewardService.canInteract(with: critter, action: .feed, context: modelContext),
                            highlighted: !wishCompleted && wish.action == .feed
                        ) {
                            interact(with: critter, action: .feed)
                        }
                        critterNestAction(
                            icon: "sparkles",
                            title: l.tr(zh: "玩耍", en: "Play", de: "Spielen"),
                            cost: critterInteractionCostText(critter, action: .play),
                            enabled: OasisUpgradeRewardService.canInteract(with: critter, action: .play, context: modelContext),
                            highlighted: !wishCompleted && wish.action == .play
                        ) {
                            interact(with: critter, action: .play)
                        }
                        critterNestAction(
                            icon: "moon.fill",
                            title: l.tr(zh: "休息", en: "Rest", de: "Ruhen"),
                            cost: "3/d",
                            enabled: OasisUpgradeRewardService.canInteract(with: critter, action: .rest, context: modelContext),
                            highlighted: !wishCompleted && wish.action == .rest
                        ) {
                            interact(with: critter, action: .rest)
                        }
                    }
                }
            }
            .padding(16)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Color.goPrimary.opacity(0.16), lineWidth: 1)
            )
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showCritterCodex = true
        }
        .accessibilityLabel(l.tr(zh: "电子宠物图鉴", en: "Critter Codex", de: "Critter-Album"))
    }

    private var featuredCritter: OasisElectronicPet? {
        electronicPets
            .filter { !$0.isArchived }
            .filter { $0.lifeState != .dead }
            .sorted {
                if $0.isFeaturedOnOasis != $1.isFeaturedOnOasis {
                    return $0.isFeaturedOnOasis && !$1.isFeaturedOnOasis
                }
                if $0.habitatSlot != $1.habitatSlot { return $0.habitatSlot < $1.habitatSlot }
                return $0.obtainedAt < $1.obtainedAt
            }
            .first
    }

    private var nextCritterMilestoneLevel: Int {
        treeMgr.treeLevel.rawValue < 5 ? 5 : 10
    }

    private var nextCritterGoalText: String {
        if treeMgr.treeLevel.rawValue < 5 {
            return l.tr(zh: "Lv.5 保底 Lumo", en: "Lv.5 guarantees Lumo", de: "Lv.5 garantiert Lumo")
        }
        if treeMgr.treeLevel.rawValue < 10 {
            return l.tr(zh: "Lv.10 保底极光灵", en: "Lv.10 guarantees Aurora Luma", de: "Lv.10 garantiert Aurora Luma")
        }
        return l.tr(zh: "传说伙伴已在树顶等待", en: "Legendary companion awaits", de: "Legendärer Begleiter wartet")
    }

    private var milestoneProgressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.ohanaControlFill)
                Capsule()
                    .fill(LinearGradient(colors: [Color.goPrimary, Color.goTeal], startPoint: .leading, endPoint: .trailing))
                    .frame(width: proxy.size.width * nextCritterProgress)
                    .animation(GoMotion.feedback, value: nextCritterProgress)
            }
        }
        .frame(height: 9)
    }

    private var nextCritterProgress: CGFloat {
        let targetEnergy = nextCritterMilestoneLevel == 5 ? 500 : 3600
        guard targetEnergy > 0 else { return 1 }
        return min(1, max(0, CGFloat(treeMgr.totalEnergy) / CGFloat(targetEnergy)))
    }

    private func critterMilestonePill(level: Int, catalogId: String) -> some View {
        let entry = OasisUpgradeRewardCatalog.critter(id: catalogId)
        let isReached = treeMgr.treeLevel.rawValue >= level
        return HStack(spacing: 8) {
            OasisCritterIllustration(catalogId: catalogId, locked: !isReached, size: 38)
            VStack(alignment: .leading, spacing: 1) {
                Text("Lv.\(level)")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(isReached ? Color.goPrimary : Color.ohanaPrimaryText)
                Text(entry?.name(l) ?? "")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(9)
        .frame(maxWidth: .infinity)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func critterQuickMetric(icon: String, value: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .black))
            Text(value)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .foregroundStyle(Color.ohanaSecondaryText)
    }

    private func critterLifeStrip(_ critter: OasisElectronicPet, snapshot: OasisCritterLifecycleSnapshot) -> some View {
        HStack(spacing: 9) {
            Image(systemName: critterLifecycleIcon(for: snapshot.state))
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(snapshot.state == .critical ? Color.arkInk : Color.ohanaPrimaryActionText)
                .frame(width: 32, height: 32)
                .background(critterLifecycleTint(for: snapshot.state), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.state.name(l))
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                Text(OasisUpgradeRewardService.gentlePrompt(for: critter, snapshot: snapshot, l: l))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func critterWishStrip(_ wish: OasisCritterDailyWish, critter: OasisElectronicPet, isCompleted: Bool) -> some View {
        HStack(spacing: 9) {
            Image(systemName: isCompleted ? "checkmark.seal.fill" : wish.icon)
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(isCompleted ? Color.arkInk : Color.ohanaPrimaryActionText)
                .frame(width: 32, height: 32)
                .background(isCompleted ? Color.goPrimary : critterRarityColor(critter.rarity), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(isCompleted ? l.tr(zh: "今日小愿望完成", en: "Tiny wish complete", de: "Kleiner Wunsch erfüllt") : wish.title(l))
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                Text(isCompleted ? l.tr(zh: "明天还有新的心愿。", en: "New wish tomorrow.", de: "Morgen gibt es einen neuen Wunsch.") : wish.rewardText(l))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(isCompleted ? Color.goPrimary : Color.ohanaSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .animation(GoMotion.feedback, value: isCompleted)
    }

    private func critterOutcomeStrip(_ outcome: OasisCritterInteractionOutcome) -> some View {
        HStack(spacing: 8) {
            Image(systemName: outcome.completedDailyWish ? "sparkles" : "heart.fill")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(outcome.completedDailyWish ? Color.arkInk : Color.goPrimary)
                .frame(width: 28, height: 28)
                .background(outcome.completedDailyWish ? Color.goYellow : Color.ohanaControlFill, in: Circle())
            Text(outcome.message(l))
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(2)
            Spacer(minLength: 0)
            let reward = outcome.rewardText(l)
            if !reward.isEmpty {
                Text(reward)
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(Color.goPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.ohanaCardSurface.opacity(0.72), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    private func critterNestAction(icon: String, title: String, cost: String, enabled: Bool = true, highlighted: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .black))
                Text(title)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                Text(cost)
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .opacity(0.62)
            }
            .foregroundStyle(highlighted ? Color.arkInk : Color.ohanaPrimaryActionText)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(enabled ? (highlighted ? Color.goYellow : Color.goPrimary) : Color.ohanaControlFill, in: Capsule())
            .opacity(enabled ? 1 : 0.5)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!enabled)
    }

    private func critterInteractionCostText(_ critter: OasisElectronicPet, action: OasisCritterAction) -> String {
        let cost = OasisUpgradeRewardService.interactionCost(for: critter, action: action, context: modelContext)
        return cost == 0 ? l.tr(zh: "免费", en: "Free", de: "Gratis") : "\(cost)🥥"
    }

    private func critterRarityColor(_ rarity: OasisElectronicPetRarity) -> Color {
        switch rarity {
        case .common: return Color.goTeal
        case .rare: return Color(hex: "7C6CFF")
        case .epic: return Color(hex: "B45CFF")
        case .legendary: return Color.goOrange
        }
    }

    private func critterLifecycleIcon(for state: OasisCritterLifeState) -> String {
        switch state {
        case .healthy: return "heart.fill"
        case .needsCare: return "hand.raised.fill"
        case .atRisk: return "exclamationmark.circle.fill"
        case .sick: return "cross.case.fill"
        case .critical: return "hourglass"
        case .dead: return "leaf.fill"
        }
    }

    private func critterLifecycleTint(for state: OasisCritterLifeState) -> Color {
        switch state {
        case .healthy: return Color.goPrimary
        case .needsCare: return Color.goTeal
        case .atRisk: return Color.goOrange
        case .sick: return Color.goPurple
        case .critical: return Color.goYellow
        case .dead: return Color.ohanaCardSurface
        }
    }

    // MARK: - Upgrade Coconut Dock

    private var oasisUpgradeRewardDock: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let reward = openedUpgradeReward {
                openedUpgradeRewardCard(reward)
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
            }

            if !pendingUpgradeCoconuts.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(Color.goPrimary)
                        Text(l.tr(zh: "升级椰子", en: "Upgrade Coconuts", de: "Upgrade-Kokosnüsse"))
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Spacer()
                        Text("\(pendingUpgradeCoconuts.count)")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryActionText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.goPrimary, in: Capsule())
                    }

                    ForEach(Array(pendingUpgradeCoconuts.prefix(3)), id: \.id) { coconut in
                        upgradeCoconutRow(coconut)
                    }
                }
            }

            if !electronicPets.isEmpty {
                critterCompanionStrip
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.ohanaPrimaryText.opacity(0.08), lineWidth: 1)
        )
    }

    private func upgradeCoconutRow(_ coconut: OasisUpgradeCoconut) -> some View {
        let isOpening = openingUpgradeCoconutId == coconut.id
        let isMilestone = coconut.rewardKind == .electronicPet
        return Button {
            openUpgradeCoconut(coconut)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isMilestone ? Color.goPrimary.opacity(0.2) : Color.ohanaControlFill)
                        .frame(width: 46, height: 46)
                    Text("🥥")
                        .font(.system(size: 26))
                        .rotationEffect(.degrees(isOpening ? -12 : 0))
                        .scaleEffect(isOpening ? 1.16 : 1)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Lv.\(coconut.level) · \(coconut.title(l))")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(isMilestone
                         ? l.tr(zh: "里程碑保底", en: "Milestone guaranteed", de: "Meilenstein garantiert")
                         : coconut.description(l))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(isMilestone ? Color.goPrimary : Color.ohanaSecondaryText)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "hammer.fill")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .frame(width: 38, height: 38)
                    .background(Color.goPrimary, in: Circle())
            }
            .padding(10)
            .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("\(coconut.title(l)) \(l.tr(zh: "敲开", en: "Open", de: "Öffnen"))")
    }

    private func openedUpgradeRewardCard(_ reward: OasisOpenedUpgradeReward) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(reward.isMilestoneCritter ? Color.goPrimary.opacity(0.22) : Color.goYellow.opacity(0.18))
                    .frame(width: 56, height: 56)
                Text(reward.emoji)
                    .font(.system(size: 30))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(reward.title(l))
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(reward.detail(l))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(2)
            }
            Spacer()
            Button {
                withAnimation(GoMotion.feedback) {
                    openedUpgradeReward = nil
                }
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .frame(width: 38, height: 38)
                    .background(Color.goPrimary, in: Circle())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(12)
        .background(Color.goPrimary.opacity(reward.isMilestoneCritter ? 0.16 : 0.08), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var critterCompanionStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Color.goPrimary)
                Text(l.tr(zh: "电子宠物", en: "Critters", de: "Critter"))
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                fragmentSummary
            }

            ForEach(Array(electronicPets.prefix(2)), id: \.id) { critter in
                critterCompanionCard(critter)
            }
        }
    }

    private var fragmentSummary: some View {
        let total = critterFragments.reduce(0) { $0 + $1.amount }
        return HStack(spacing: 4) {
            Text("◇")
                .font(.system(size: 12, weight: .black))
            Text("\(total)")
                .font(.system(size: 12, weight: .black, design: .rounded))
        }
        .foregroundStyle(Color.goPrimary)
    }

    private func critterCompanionCard(_ critter: OasisElectronicPet) -> some View {
        let snapshot = OasisUpgradeRewardService.lifecycleSnapshot(for: critter, context: modelContext)
        let isDead = snapshot.state == .dead
        return HStack(spacing: 12) {
            OasisCritterIllustration(catalogId: critter.catalogId, locked: false, size: 58, critter: critter)
                .scaleEffect(critterActionPulseId == critter.id ? 1.08 : 1)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(critter.displayName(l))
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(l.tr(zh: critter.rarity.zh, en: critter.rarity.en, de: critter.rarity.de))
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryActionText)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.goPrimary, in: Capsule())
                }

                HStack(spacing: 6) {
                    critterMeter(value: critter.hunger, icon: "fork.knife")
                    critterMeter(value: critter.mood, icon: "face.smiling")
                    critterMeter(value: critter.health, icon: "cross.case.fill")
                    critterMeter(value: OasisUpgradeRewardService.bondProgress(for: critter), icon: "heart.fill")
                }
                Text(snapshot.state.name(l))
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(isDead ? Color.ohanaTertiaryText : Color.goPrimary)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 7) {
                if snapshot.isRescuable {
                    critterActionButton(icon: "cross.case.fill", cost: l.tr(zh: "免费", en: "Free", de: "Gratis"), enabled: rescuingCritterId != critter.id) {
                        rescue(with: critter)
                    }
                } else {
                    critterActionButton(
                        icon: "carrot.fill",
                        cost: critterInteractionCostText(critter, action: .feed),
                        enabled: OasisUpgradeRewardService.canInteract(with: critter, action: .feed, context: modelContext)
                    ) {
                        interact(with: critter, action: .feed)
                    }
                    critterActionButton(
                        icon: "sparkles",
                        cost: critterInteractionCostText(critter, action: .play),
                        enabled: OasisUpgradeRewardService.canInteract(with: critter, action: .play, context: modelContext)
                    ) {
                        interact(with: critter, action: .play)
                    }
                    let starCost = OasisUpgradeRewardService.starUpgradeCost(for: critter)
                    critterActionButton(
                        icon: "star.fill",
                        cost: "\(starCost.fragments)◇",
                        enabled: !isDead && OasisCritterEconomyService.canSpendCurrentHumanCoconuts(starCost.coconuts, context: modelContext)
                    ) {
                        upgradeCritterStar(critter)
                    }
                }
            }
        }
        .padding(10)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func critterMeter(value: Int, icon: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .bold))
            Text("\(max(0, min(100, value)))")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .contentTransition(.numericText())
        }
        .foregroundStyle(Color.ohanaSecondaryText)
    }

    private func critterActionButton(icon: String, cost: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .black))
                Text(cost)
                    .font(.system(size: 8, weight: .black, design: .rounded))
            }
            .foregroundStyle(Color.ohanaPrimaryActionText)
            .frame(width: 42, height: 42)
            .background(enabled ? Color.goPrimary : Color.ohanaControlFill, in: Circle())
            .opacity(enabled ? 1 : 0.5)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!enabled)
    }

    private func openUpgradeCoconut(_ coconut: OasisUpgradeCoconut) {
        guard openingUpgradeCoconutId == nil else { return }
        openingUpgradeCoconutId = coconut.id
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(GoMotion.feedback) {
            openedUpgradeReward = nil
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            do {
                let result = try OasisUpgradeRewardService.open(coconut, context: modelContext)
                UINotificationFeedbackGenerator().notificationOccurred(result.isMilestoneCritter ? .success : .warning)
                withAnimation(GoMotion.fab) {
                    openedUpgradeReward = result
                    openingUpgradeCoconutId = nil
                }
                if result.isMilestoneCritter {
                    spawnEnergyParticles(count: 16)
                }
            } catch {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                withAnimation(GoMotion.feedback) {
                    openingUpgradeCoconutId = nil
                }
            }
        }
    }

    private func interact(with critter: OasisElectronicPet, action: OasisCritterAction) {
        do {
            let outcome = try OasisUpgradeRewardService.interactWithOutcome(with: critter, action: action, context: modelContext)
            if outcome.success {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(GoMotion.feedback) {
                    critterActionPulseId = critter.id
                    lastCritterInteractionOutcome = outcome
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    withAnimation(GoMotion.feedback) {
                        critterActionPulseId = nil
                    }
                }
                clearCritterInteractionOutcomeLater(outcome)
            } else {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func rescue(with critter: OasisElectronicPet) {
        guard rescuingCritterId == nil else { return }
        rescuingCritterId = critter.id
        defer { clearRescueBusyState(for: critter.id) }

        do {
            let outcome = try OasisUpgradeRewardService.rescueIfNeeded(for: critter, context: modelContext)
            if outcome.success {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(GoMotion.feedback) {
                    critterActionPulseId = critter.id
                    lastCritterInteractionOutcome = outcome
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    withAnimation(GoMotion.feedback) {
                        critterActionPulseId = nil
                    }
                }
                clearCritterInteractionOutcomeLater(outcome)
            } else {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func clearRescueBusyState(for critterId: UUID) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            guard rescuingCritterId == critterId else { return }
            rescuingCritterId = nil
        }
    }

    private func refreshFeaturedCritterLifecycle() {
        for critter in electronicPets where !critter.isArchived {
            OasisUpgradeRewardService.normalizeLifecycle(for: critter, context: modelContext)
        }
    }

    private func clearCritterInteractionOutcomeLater(_ outcome: OasisCritterInteractionOutcome) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.4) {
            guard lastCritterInteractionOutcome == outcome else { return }
            withAnimation(GoMotion.reduced) {
                lastCritterInteractionOutcome = nil
            }
        }
    }

    private func upgradeCritterStar(_ critter: OasisElectronicPet) {
        do {
            if try OasisUpgradeRewardService.upgradeStar(for: critter, context: modelContext) {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                withAnimation(GoMotion.fab) {
                    critterActionPulseId = critter.id
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    withAnimation(GoMotion.feedback) {
                        critterActionPulseId = nil
                    }
                }
            } else {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    // MARK: - Progress Card

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Title row
            HStack {
                Text("成长进度")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                Text("能量 \(treeMgr.totalEnergy) · 下一级 \(treeMgr.nextLevelThreshold)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.ohanaControlFill)
                        .frame(height: 8)
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Color.goPrimary, Color.goTeal],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(width: geo.size.width * treeMgr.progressToNextLevel, height: 8)
                        .shadow(color: Color.goPrimary.opacity(0.5), radius: 6, x: 0, y: 0) // ui-v4: allow Oasis progress shine
                        .animation(GoMotion.page, value: treeMgr.progressToNextLevel)
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
                        : Color.ohanaSecondaryText.opacity(0.6)
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
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.ohanaPrimaryText.opacity(0.08), lineWidth: 1)
        )
    }

    private func progressStatCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Inject Energy Button

    private var injectEnergyButton: some View {
        let canInject = OasisCritterEconomyService.canSpendCurrentHumanCoconuts(10, context: modelContext)
        return Button {
            let beforeLevel = treeMgr.treeLevel
            withAnimation { isInjecting = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation { isInjecting = false }
            }
            if treeMgr.injectEnergy(cost: 10, modelContext: modelContext) {
                spawnEnergyParticles(count: 10)
                if treeMgr.treeLevel != beforeLevel {
                    triggerLevelUpFeedback()
                }
            } else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        } label: {
            HStack(spacing: 8) {
                Text("⚡")
                Text("注入能量")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                Text("(-10🥥)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryActionText.opacity(0.55))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                canInject ? Color.goPrimary : Color.ohanaControlFill,
                in: Capsule()
            )
            .overlay(Capsule().strokeBorder(
                canInject ? Color.clear : Color.ohanaPrimaryText.opacity(0.08),
                lineWidth: 1
            ))
        }
        .buttonStyle(ScaleButtonStyle())
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
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text("生命之树已至巅峰，繁荣永续")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.ohanaSecondaryText)
                    } else {
                        Text("Lv.\(nextLv) · \(nextLevel.displayName)")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text("解锁被动收益 +\(passiveIncomeForLevel(nextLevel))🥥/日")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.goPrimary.opacity(0.8))
                    }
                }

                Spacer()

                if !isMaxLevel {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
            }
            .padding(16)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.ohanaPrimaryText.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
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
                        .foregroundStyle(Color.ohanaPrimaryText)
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
                    withAnimation(GoMotion.quick) {
                        calendarDisplayMonth = Calendar.current.date(byAdding: .month, value: -1, to: calendarDisplayMonth) ?? calendarDisplayMonth
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.5))
                }
                Spacer()
                Text(monthYearString(calendarDisplayMonth))
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                Button {
                    let next = Calendar.current.date(byAdding: .month, value: 1, to: calendarDisplayMonth) ?? calendarDisplayMonth
                    if next <= Date() {
                        withAnimation(GoMotion.quick) { calendarDisplayMonth = next }
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
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.3))
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
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.7))
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
                    Button {
                        coconutShopInitialCategory = .boost
                        showCoconutShop = true
                    } label: {
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
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.35))
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
                                .foregroundStyle(Color.ohanaPrimaryActionText)
                            Spacer()
                            Text("+\(m.reward)🥥 领取")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.ohanaPrimaryActionText.opacity(0.72))
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(Color.goPrimary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())
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
                                .foregroundStyle(Color.ohanaPrimaryActionText.opacity(0.72))
                        } else {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .black))
                                .foregroundStyle(Color.ohanaPrimaryActionText)
                        }
                    } else {
                        Text("\(cell.day)")
                            .font(.system(size: 11, weight: cell.isToday ? .black : .medium, design: .rounded))
                            .foregroundStyle(
                                cell.isFuture ? Color.ohanaSecondaryText.opacity(0.35) :
                                cell.isToday ? Color.goPrimary : Color.ohanaSecondaryText
                            )
                    }
                }
            }
            .buttonStyle(ScaleButtonStyle())
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
            return Color.ohanaControlFill
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
        CheckInStreakStore.dateString()
    }

    private var currentStreak: Int {
        CheckInStreakStore.currentStreak(for: currentActiveHumanId)
    }

    private var longestStreak: Int {
        CheckInStreakStore.longestStreak(for: currentActiveHumanId)
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
        checkedInDates = CheckInStreakStore.checkedInDates(for: currentActiveHumanId)
        makeupDates = CheckInStreakStore.makeupDates(for: currentActiveHumanId)
        makeupPackCount = UserDefaults.standard.integer(forKey: CheckInStreakStore.makeupPackKey)
        lastClaimedMilestone = CheckInStreakStore.lastClaimedMilestone(for: currentActiveHumanId)
    }

    private func triggerTodayCheckIn() {
        let today = todayStr()
        guard !checkedInDates.contains(today) else { return }
        checkedInDates.insert(today)
        CheckInStreakStore.setCheckedInDates(checkedInDates, for: currentActiveHumanId)
        OasisCritterEconomyService.awardCurrentHumanCoconuts(1, emoji: "📅", title: "每日打卡奖励", context: modelContext)
        modelContext.safeSave()
    }

    private func applyMakeup(date: String) {
        guard makeupPackCount > 0, !checkedInDates.contains(date) else { return }
        makeupPackCount -= 1
        UserDefaults.standard.set(makeupPackCount, forKey: CheckInStreakStore.makeupPackKey)
        checkedInDates.insert(date)
        makeupDates.insert(date)
        CheckInStreakStore.setCheckedInDates(checkedInDates, for: currentActiveHumanId)
        CheckInStreakStore.setMakeupDates(makeupDates, for: currentActiveHumanId)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func claimMilestone(_ days: Int, reward: Int, emoji: String) {
        OasisCritterEconomyService.awardCurrentHumanCoconuts(reward, emoji: emoji, title: "\(days)天连胜奖励", context: modelContext)
        modelContext.safeSave()
        lastClaimedMilestone = days
        CheckInStreakStore.setLastClaimedMilestone(days, for: currentActiveHumanId)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // MARK: - Bento Dynamic Subtitles

    private var shopSubtitle: String {
        let canAfford = activeHumanCoconutBalance >= 25
        return canAfford ? "13件道具 · 最低25🥥" : "攒够椰子再来"
    }

    private var gachaSubtitle: String {
        "80🥥/次 · 不限次数"
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
                bentoMiniCard(emoji: "🛒", title: l.tr(zh: "商店", en: "Shop", de: "Shop"),
                    metric: "🥥 \(activeHumanCoconutBalance)", accent: Color.goYellow,
                    action: {
                        coconutShopInitialCategory = .effect
                        showCoconutShop = true
                    })
                bentoMiniCard(emoji: "🏆", title: l.tr(zh: "成就", en: "Awards", de: "Erfolge"),
                    metric: noPet ? "—" : "\(unlockedCount)/\(totalCount)",
                    accent: noPet ? Color.ohanaSecondaryText : Color.goTeal,
                    action: { if !noPet { showAchievements = true } })
                    .opacity(noPet ? 0.55 : 1)
            }
            // 行二：伙伴图鉴 + 盲盒
            HStack(spacing: 8) {
                bentoMiniCard(emoji: "🐾", title: l.tr(zh: "伙伴", en: "Critters", de: "Critter"),
                    metric: electronicPets.isEmpty ? "Lv.5" : "\(electronicPets.filter { !$0.isArchived }.count)/\(OasisUpgradeRewardCatalog.critters.count)",
                    accent: Color.goTeal,
                    action: { showCritterCodex = true })
                bentoMiniCard(emoji: "🎁", title: l.tr(zh: "盲盒", en: "Blind Box", de: "Blind Box"),
                    metric: "80🥥", accent: Color.goPrimary,
                    action: {
                        withAnimation(GoMotion.page) {
                            showGacha = true
                        }
                    })
            }
        }
    }

    private func bentoMiniCard(emoji: String, title: String, metric: String, accent: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(emoji).font(.system(size: 24))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(metric)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(accent)
                        .monospacedDigit()
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .background(
                Color.ohanaCardSurface,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.ohanaPrimaryText.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Animations

    private func startAmbientMotionIfNeeded() {
        updateGlowMotion()
        updateHarvestBubbleMotion()
        startBreathing()
    }

    private func stopAmbientMotion() {
        glowBreathing = false
        harvestBubbleBounce = false
        treeScale = 1.0
        treeGlow = 0.4
    }

    private func updateGlowMotion() {
        glowBreathing = shouldRunAmbientMotion
    }

    private func updateHarvestBubbleMotion() {
        harvestBubbleBounce = shouldRunAmbientMotion
    }

    private func startBreathing() {
        guard shouldRunAmbientMotion else {
            treeScale = 1.0
            treeGlow = 0.4
            return
        }
        withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) { // ui-v4: allow AppWorkloadPolicy-gated Oasis ambient breathing
            treeScale = 1.055
            treeGlow  = 0.7
        }
    }

    private func triggerLevelUpFeedback() {
        guard !levelUpPulse else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        spawnEnergyParticles(count: 22)
        withAnimation(GoMotion.fab) {
            levelUpPulse = true
            levelUpBadgeVisible = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(GoMotion.hero) {
                levelUpPulse = false
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.35) {
            withAnimation(GoMotion.quick) {
                levelUpBadgeVisible = false
            }
        }
    }

    private func spawnEnergyParticles(count: Int = 8) {
        energyParticles = (0..<count).map { _ in EnergyParticle() }
        for i in energyParticles.indices {
            withAnimation(.easeOut(duration: Double.random(in: 0.85...1.55)).delay(Double(i) * 0.035)) { // ui-v4: allow short reward particle burst
                energyParticles[i].offsetY  = CGFloat.random(in: -180 ... -80)
                energyParticles[i].opacity  = 0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.75) {
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
        RuleCard(emoji: "🦮", title: "遛狗", desc: "带毛孩子出门溜达", glowColor: Color(hex: "14B8A6"), reward: "每100m得1🥥"),
        RuleCard(emoji: "🍗", title: "喂食·喂水", desc: "按时投喂，爱意满满", glowColor: Color(hex: "FF8C42"), reward: "每次2~3🥥"),
        RuleCard(emoji: "🧹", title: "铲屎官在线", desc: "勤劳铲屎，功德无量", glowColor: Color(hex: "A8E6CF"), reward: "每次5~8🥥"),
        RuleCard(emoji: "🪮", title: "护理·梳毛", desc: "精心打理，美美的", glowColor: Color(hex: "DDA0DD"), reward: "5~10🥥，洗澡15🥥"),
        RuleCard(emoji: "💉", title: "健康打卡", desc: "关注健康，守护生命", glowColor: Color(hex: "FF6B6B"), reward: "每次20🥥"),
        RuleCard(emoji: "💰", title: "记一笔账", desc: "精打细算，爱的花销", glowColor: Color(hex: "FFD93D"), reward: "每次10🥥"),
        RuleCard(emoji: "🎾", title: "逗玩互动", desc: "玩耍时光最快乐", glowColor: Color(hex: "6BCB77"), reward: "每次10~12🥥"),
        RuleCard(emoji: "🌳", title: "每日掉落", desc: "生命之树被动收益", glowColor: Color(hex: "84CC16"), reward: "定时领取"),
        RuleCard(emoji: "🎲", title: "暴击加成", desc: "幸运降临！", glowColor: Color(hex: "FFCC00"), reward: "10%双倍·1%五倍🔥"),
    ]

    private let spendCards: [RuleCard] = [
        RuleCard(emoji: "✨", title: "注入生命之树", desc: "让生命之树更旺盛", glowColor: Color(hex: "F59E0B"), reward: "每次10🥥"),
        RuleCard(emoji: "🛍️", title: "椰子商店", desc: "兑换特效/称号/加成", glowColor: Color(hex: "667eea"), reward: "各种道具"),
        RuleCard(emoji: "🎁", title: "盲盒", desc: "系列盲盒收藏", glowColor: Color(hex: "FF6B9D"), reward: "80🥥/次"),
        RuleCard(emoji: "🎯", title: "悬赏任务", desc: "发布·接单·奖励", glowColor: Color(hex: "FF8C42"), reward: "转给完成者"),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                OhanaAppBackground().ignoresSafeArea()

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
                            doubleAccountRow(emoji: "🏝️", title: "全岛总库", desc: "统计全家椰子流动")
                        }
                        .padding(14)
                        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color.ohanaPrimaryText.opacity(0.08), lineWidth: 1))

                        // ── 底部口号
                        HStack {
                            Spacer()
                            VStack(spacing: 6) {
                                Text("💡")
                                    .font(.system(size: 28))
                                Text("打卡次数越多，椰子越多，生命之树越旺！")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.35))
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("关闭")
                }
            }
        }
        .presentationDetents([.large]) // ui-v4: allow rules reference sheet
        .presentationDragIndicator(.visible)
        .onAppear {
            withAnimation(GoMotion.page) { appeared = true }
        }
    }

    @ViewBuilder
    private func bentoCategoryHeader(emoji: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(emoji).font(.system(size: 18))
                Text(title)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
            }
            Text(subtitle)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
        }
    }

    @ViewBuilder
    private func bentoCard(_ card: RuleCard, delay: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(card.emoji)
                .font(.system(size: 28))
            Text(card.title)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(card.desc)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.45))
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
            Color.ohanaCardSurface,
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.ohanaPrimaryText.opacity(0.08), lineWidth: 1)
        )
        .scaleEffect(appeared ? 1 : 0.88)
        .opacity(appeared ? 1 : 0)
        .animation(GoMotion.page.delay(delay), value: appeared)
    }

    @ViewBuilder
    private func doubleAccountRow(emoji: String, title: String, desc: String) -> some View {
        HStack(spacing: 12) {
            Text(emoji).font(.system(size: 20)).frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(desc)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
            }
            Spacer()
        }
    }
}

private struct OasisCritterUnlockRewardCard: View {
    let catalogId: String
    let newLabel: String
    let rarityText: String
    let title: String
    let detail: String
    let confirmTitle: String
    let accent: Color
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 13) {
            Text(newLabel)
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaPrimaryActionText)
                .padding(.horizontal, 13)
                .padding(.vertical, 6)
                .background(accent, in: Capsule())
                .scaleEffect(appeared && !reduceMotion ? 1 : 0.82)

            ZStack {
                unlockRing(size: 214, delay: 0)
                unlockRing(size: 174, delay: 0.06)
                unlockSparkles

                Circle()
                    .fill(accent.opacity(0.18))
                    .frame(width: 150, height: 150)
                    .blur(radius: 8)
                    .scaleEffect(appeared ? 1.08 : 0.72)

                OasisCritterIllustration(catalogId: catalogId, locked: false, size: 176)
                    .scaleEffect(appeared && !reduceMotion ? 1 : 0.72)
                    .offset(y: appeared ? 0 : 12)
            }
            .frame(height: 220)

            VStack(spacing: 5) {
                Text(title)
                    .font(OhanaFont.title2(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(rarityText)
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(accent)

                Text(detail)
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 10)
            }

            Button(action: onClose) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                    Text(confirmTitle)
                }
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaPrimaryActionText)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(Color.goPrimary, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(16)
        .frame(maxWidth: 344)
        .background(Color.ohanaCardSurface.opacity(0.96), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(accent.opacity(0.32), lineWidth: 1.2)
        }
        .shadow(color: accent.opacity(0.26), radius: 28, x: 0, y: 12) // ui-v4: allow transient electronic-pet unlock focus
        .scaleEffect(appeared && !reduceMotion ? 1 : 0.9)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(reduceMotion ? GoMotion.reduced : GoMotion.fab) {
                appeared = true
            }
        }
    }

    private func unlockRing(size: CGFloat, delay: Double) -> some View {
        Circle()
            .stroke(accent.opacity(appeared ? 0 : 0.62), lineWidth: 2)
            .frame(width: size, height: size)
            .scaleEffect(appeared && !reduceMotion ? 1.12 : 0.68)
            .animation((reduceMotion ? GoMotion.reduced : GoMotion.hero).delay(delay), value: appeared)
    }

    private var unlockSparkles: some View {
        ZStack {
            ForEach(0..<10, id: \.self) { index in
                let angle = Angle.degrees(Double(index) * 36)
                Image(systemName: index.isMultiple(of: 2) ? "sparkle" : "star.fill")
                    .font(.system(size: index.isMultiple(of: 2) ? 13 : 8, weight: .black))
                    .foregroundStyle(index.isMultiple(of: 2) ? Color.goYellow : accent)
                    .offset(
                        x: appeared && !reduceMotion ? cos(angle.radians) * 104 : cos(angle.radians) * 58,
                        y: appeared && !reduceMotion ? sin(angle.radians) * 92 : sin(angle.radians) * 44
                    )
                    .opacity(appeared ? 1 : 0)
                    .animation((reduceMotion ? GoMotion.reduced : GoMotion.fab).delay(0.02 * Double(index)), value: appeared)
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    OasisRewardView()
        .modelContainer(SharedModelContainer.make())
}
