//
//  OasisRewardView.swift
//  Ohana
//
//  绿洲圣地 — 生命之树动态进化 + 注入能量 + Bento 功能区
//

import SwiftUI
import SwiftData

private struct OasisRewardPresentationModifier: ViewModifier {
    @Binding var showingCoconutLog: Bool
    @Binding var showCoconutRules: Bool
    @Binding var showAchievements: Bool
    @Binding var showInventory: Bool
    @Binding var showCoconutShop: Bool
    @Binding var showGacha: Bool
    @Binding var showCheckInSheet: Bool
    @Binding var showCritterCodex: Bool
    let pets: [Pet]
    let coconutShopInitialCategory: ShopItem.ShopCategory

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $showingCoconutLog) { CoconutLogView() }
            .sheet(isPresented: $showCoconutRules) {
                CoconutRulesSheet()
                    .ohanaSheetPagePresentation() // ui-v4: allow rules reference sheet
            }
            .sheet(isPresented: $showAchievements) {
                if let pet = pets.first {
                    AchievementWallView(pet: pet, allPets: pets)
                        .ohanaSheetPagePresentation() // ui-v4: allow long achievement overview
                }
            }
            .sheet(isPresented: $showInventory) {
                InventoryView()
                    .ohanaSheetPagePresentation() // ui-v4: allow long inventory overview
            }
            .sheet(isPresented: $showCoconutShop) {
                CoconutShopView(initialCategory: coconutShopInitialCategory)
                    .ohanaSheetPagePresentation() // ui-v4: allow long shop overview
            }
            .sheet(isPresented: $showGacha) {
                GachaView()
                    .ohanaSheetPagePresentation() // ui-v4: allow long blind-box overview
            }
            .sheet(isPresented: $showCheckInSheet) {
                DailyStreakDetailView(pets: pets, onClose: { showCheckInSheet = false })
                    .ohanaSheetPagePresentation() // ui-v4: allow long streak overview
            }
            .sheet(isPresented: $showCritterCodex) {
                OasisCritterCodexView(mode: .codex)
                    .ohanaSheetPagePresentation() // ui-v4: allow long critter codex overview
            }
    }
}

private struct OasisRewardRuntimeModifier: ViewModifier {
    let shouldRunAmbientMotion: Bool
    let currentActiveHumanId: String
    let petsCount: Int
    let humansCount: Int
    let plantsCount: Int
    let electronicPetsCount: Int
    let critterFragmentsCount: Int
    let activeHumanCoconutBalance: Int
    let rulesTrigger: Bool
    let inventoryTrigger: Bool
    let injectEnergyTrigger: Int
    let isEmbeddedPrepared: Bool
    let isEmbeddedVisible: Bool
    let isEmbeddedActive: Bool
    let makeupConfirmationTitle: String
    let makeupConfirmationBinding: Binding<Bool>
    @Binding var showMakeupConfirm: String?
    @Binding var showCoconutRules: Bool
    @Binding var showInventory: Bool
    let onAppearAction: () -> Void
    let onDisappearAction: () -> Void
    let onAmbientMotionChanged: (Bool) -> Void
    let onActiveHumanChanged: () -> Void
    let onRefreshOasisEnergy: () -> Void
    let onRefreshFeaturedCritterLifecycle: () -> Void
    let onRefreshRenderSnapshots: () -> Void
    let onInjectTreeEnergy: () -> Void
    let onEmbeddedPreparedChanged: (Bool) -> Void
    let onEmbeddedVisibleChanged: (Bool) -> Void
    let onEmbeddedActiveChanged: (Bool) -> Void
    let onApplyMakeup: (String) -> Void

    func body(content: Content) -> some View {
        content
            .onAppear(perform: onAppearAction)
            .onDisappear(perform: onDisappearAction)
            .onChange(of: shouldRunAmbientMotion) { _, shouldAnimate in
                onAmbientMotionChanged(shouldAnimate)
            }
            .onChange(of: currentActiveHumanId) { _, _ in
                onActiveHumanChanged()
            }
            .modifier(makeupConfirmationModifier)
            .onChange(of: petsCount) { onRefreshOasisEnergy() }
            .onChange(of: humansCount) { onRefreshOasisEnergy() }
            .onChange(of: plantsCount) { onRefreshOasisEnergy() }
            .onChange(of: electronicPetsCount) { _, _ in onRefreshFeaturedCritterLifecycle() }
            .onChange(of: critterFragmentsCount) { _, _ in onRefreshRenderSnapshots() }
            .onChange(of: activeHumanCoconutBalance) { _, _ in onRefreshRenderSnapshots() }
            .onChange(of: rulesTrigger) { _, _ in showCoconutRules = true }
            .onChange(of: inventoryTrigger) { _, _ in showInventory = true }
            .onChange(of: injectEnergyTrigger) { _, _ in onInjectTreeEnergy() }
            .onChange(of: isEmbeddedPrepared) { _, isPrepared in onEmbeddedPreparedChanged(isPrepared) }
            .onChange(of: isEmbeddedVisible) { _, isVisible in onEmbeddedVisibleChanged(isVisible) }
            .onChange(of: isEmbeddedActive) { _, isActive in onEmbeddedActiveChanged(isActive) }
    }

    private var makeupConfirmationModifier: some ViewModifier {
        OasisRewardMakeupConfirmationModifier(
            makeupConfirmationTitle: makeupConfirmationTitle,
            makeupConfirmationBinding: makeupConfirmationBinding,
            showMakeupConfirm: $showMakeupConfirm,
            onApplyMakeup: onApplyMakeup
        )
    }
}

private struct OasisRewardMakeupConfirmationModifier: ViewModifier {
    let makeupConfirmationTitle: String
    let makeupConfirmationBinding: Binding<Bool>
    @Binding var showMakeupConfirm: String?
    let onApplyMakeup: (String) -> Void

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                makeupConfirmationTitle,
                isPresented: makeupConfirmationBinding,
                titleVisibility: .visible
            ) {
                Button("消耗1个补签包确认补签") {
                    if let date = showMakeupConfirm {
                        onApplyMakeup(date)
                    }
                    showMakeupConfirm = nil
                }
                Button("取消", role: .cancel) {
                    showMakeupConfirm = nil
                }
            }
    }
}

private final class OasisTreeHarvestBuffer {
    var pendingCount = 0
    var commitTask: Task<Void, Never>?
}

struct OasisRewardView: View {
    var hideToolbar: Bool = false
    var rulesTrigger: Bool = false
    var inventoryTrigger: Bool = false
    var injectEnergyTrigger: Int = 0
    var isEmbeddedPrepared: Bool = true
    var isEmbeddedVisible: Bool = true
    var isEmbeddedActive: Bool = true

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
    @State private var critterNestPopupProgress: CGFloat = 0
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
    @State private var treeVisualEnergyOverride: Int?
    @State private var coconutBalanceVisualOverride: Int?
    @State private var isVisible = false
    @State private var isVisibleStatePrepared = false
    @State private var actionSnapshot = OasisRewardActionSnapshot()
    @State private var bentoSnapshot = OasisBentoSnapshot()
    @State private var critterRenderSnapshots: [UUID: OasisCritterRenderSnapshot] = [:]
    @State private var canHarvestTreeToday = false
    @State private var treePassiveIncomeAmount = 0
    @State private var preparedWorkTask: Task<Void, Never>?
    @State private var visibleWorkTask: Task<Void, Never>?
    @State private var renderSnapshotTask: Task<Void, Never>?
    @State private var treeCommandTask: Task<Void, Never>?
    @State private var upgradeRewardTask: Task<Void, Never>?
    @State private var critterCommandTask: Task<Void, Never>?
    @State private var checkInCommandTask: Task<Void, Never>?
    @State private var critterNestOpenTask: Task<Void, Never>?
    @State private var critterNestCloseTask: Task<Void, Never>?
    @State private var injectionResetTask: Task<Void, Never>?
    @State private var levelUpFeedbackTask: Task<Void, Never>?
    @State private var particleCleanupTask: Task<Void, Never>?
    @State private var critterPulseCleanupTask: Task<Void, Never>?
    @State private var critterOutcomeCleanupTask: Task<Void, Never>?
    @State private var rescueBusyCleanupTask: Task<Void, Never>?
    @State private var treeHarvestBuffer = OasisTreeHarvestBuffer()
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

    private let treeMgr = OasisTreeManager.shared
    private var l: L10n { L10n(appLanguage) }
    private var commandExecutor: OasisRewardCommandExecutor {
        OasisRewardCommandExecutor(context: modelContext)
    }

    private var treeVisualTotalEnergy: Int {
        treeVisualEnergyOverride ?? treeMgr.totalEnergy
    }

    private var treeVisualLevel: TreeLevel {
        OasisTreeManager.treeLevel(forTotalEnergy: treeVisualTotalEnergy)
    }

    private var treeVisualProgressToNextLevel: Double {
        OasisTreeManager.progressToNextLevel(forTotalEnergy: treeVisualTotalEnergy)
    }

    private var treeVisualNextLevelThreshold: Int {
        OasisTreeManager.nextLevelThreshold(forTotalEnergy: treeVisualTotalEnergy)
    }

    private var pendingUpgradeCoconuts: [OasisUpgradeCoconut] {
        upgradeCoconuts
            .filter { !$0.isOpened }
            .sorted { $0.level < $1.level }
    }

    private var activeHuman: Human? {
        humans.first { $0.id.uuidString == currentActiveHumanId }
    }

    private var activeHumanCoconutBalance: Int {
        if let coconutBalanceVisualOverride {
            return coconutBalanceVisualOverride
        }
        return actionSnapshot.activeCoconutBalance > 0
            ? actionSnapshot.activeCoconutBalance
            : (activeHuman?.coconutBalance ?? QuestManager.shared.coconutCount)
    }

    private var canInjectTreeEnergy: Bool {
        actionSnapshot.canInjectCoconuts ?? (activeHumanCoconutBalance >= 10)
    }

    private var contentTopInset: CGFloat {
        hideToolbar ? 32 : 64
    }

    private var treeSceneTopPadding: CGFloat {
        hideToolbar ? 10 : 12
    }

    private var shouldRunAmbientMotion: Bool {
        workloadPolicy.shouldAnimate(isVisible: isVisible && isVisibleStatePrepared)
    }

    private var isOasisPrepared: Bool {
        isEmbeddedPrepared || isEmbeddedVisible || isEmbeddedActive
    }

    private var shouldTreatEmbeddedAsVisible: Bool {
        isEmbeddedVisible || isEmbeddedActive
    }

    private var makeupConfirmationTitle: String {
        showMakeupConfirm.map { "补签 \($0)？" } ?? ""
    }

    private var makeupConfirmationBinding: Binding<Bool> {
        Binding(
            get: { showMakeupConfirm != nil },
            set: { newValue in
                if !newValue {
                    showMakeupConfirm = nil
                }
            }
        )
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
            OhanaFeedback.light()
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
        oasisRuntimeContent
    }

    private var oasisRuntimeContent: AnyView {
        AnyView(
            oasisPresentedContent
                .modifier(
                    OasisRewardRuntimeModifier(
                        shouldRunAmbientMotion: shouldRunAmbientMotion,
                        currentActiveHumanId: currentActiveHumanId,
                        petsCount: pets.count,
                        humansCount: humans.count,
                        plantsCount: plants.count,
                        electronicPetsCount: electronicPets.count,
                        critterFragmentsCount: critterFragments.count,
                        activeHumanCoconutBalance: activeHumanCoconutBalance,
                        rulesTrigger: rulesTrigger,
                        inventoryTrigger: inventoryTrigger,
                        injectEnergyTrigger: injectEnergyTrigger,
                        isEmbeddedPrepared: isEmbeddedPrepared,
                        isEmbeddedVisible: isEmbeddedVisible,
                        isEmbeddedActive: isEmbeddedActive,
                        makeupConfirmationTitle: makeupConfirmationTitle,
                        makeupConfirmationBinding: makeupConfirmationBinding,
                        showMakeupConfirm: $showMakeupConfirm,
                        showCoconutRules: $showCoconutRules,
                        showInventory: $showInventory,
                        onAppearAction: handleOasisAppear,
                        onDisappearAction: deactivateVisibleWork,
                        onAmbientMotionChanged: handleAmbientMotionChanged,
                        onActiveHumanChanged: handleActiveHumanChanged,
                        onRefreshOasisEnergy: refreshOasisEnergyIfActive,
                        onRefreshFeaturedCritterLifecycle: refreshFeaturedCritterLifecycleIfActive,
                        onRefreshRenderSnapshots: { scheduleOasisRenderSnapshotRefresh() },
                        onInjectTreeEnergy: injectTreeEnergyIfActive,
                        onEmbeddedPreparedChanged: handleEmbeddedPreparedChanged,
                        onEmbeddedVisibleChanged: handleEmbeddedVisibleChanged,
                        onEmbeddedActiveChanged: handleEmbeddedActiveChanged,
                        onApplyMakeup: applyMakeup
                    )
                )
        )
    }

    private var oasisPresentedContent: AnyView {
        AnyView(
            oasisRootContent
                .modifier(
                    OasisRewardPresentationModifier(
                        showingCoconutLog: $showingCoconutLog,
                        showCoconutRules: $showCoconutRules,
                        showAchievements: $showAchievements,
                        showInventory: $showInventory,
                        showCoconutShop: $showCoconutShop,
                        showGacha: $showGacha,
                        showCheckInSheet: $showCheckInSheet,
                        showCritterCodex: $showCritterCodex,
                        pets: pets,
                        coconutShopInitialCategory: coconutShopInitialCategory
                    )
                )
        )
    }

    private var oasisRootContent: some View {
        ZStack {
            oasisBackgroundLayer

            energyParticleLayer
                .zIndex(99)

            oasisScrollContent

            oasisToolbarLayer

            critterNestLayer
        }
    }

    private var oasisBackgroundLayer: some View {
        OhanaAppBackground()
            .ignoresSafeArea()
    }

    private var energyParticleLayer: some View {
        ForEach(energyParticles) { p in
            Text("✨")
                .font(.system(size: 22))
                .offset(x: p.offsetX, y: p.offsetY)
                .opacity(p.opacity)
                .allowsHitTesting(false)
        }
    }

    private var oasisScrollContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer().frame(height: contentTopInset)

                treeSceneCard
                    .padding(.horizontal, 16)
                    .padding(.top, treeSceneTopPadding)

                oasisBentoGrid
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 140)
            }
        }
    }

    @ViewBuilder
    private var oasisToolbarLayer: some View {
        if !hideToolbar {
            oasisFixedToolbar
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .zIndex(120)
        }
    }

    @ViewBuilder
    private var critterNestLayer: some View {
        if showCritterNest || critterNestPopupProgress > 0.001 {
            critterNestPopupOverlay
                .zIndex(180)
        }
    }

    private func handleOasisAppear() {
        if isOasisPrepared {
            prepareVisibleShell()
        }
        if shouldTreatEmbeddedAsVisible {
            activateVisiblePresentation()
        }
        if isEmbeddedActive {
            activateVisibleWork()
        }
    }

    private func handleEmbeddedPreparedChanged(_ isPrepared: Bool) {
        if isPrepared {
            prepareVisibleShell()
        } else if !shouldTreatEmbeddedAsVisible {
            deactivateVisibleWork()
        }
    }

    private func handleEmbeddedVisibleChanged(_ isVisible: Bool) {
        if isVisible {
            activateVisiblePresentation()
        } else if !isEmbeddedActive {
            deactivateVisiblePresentation()
        }
    }

    private func handleEmbeddedActiveChanged(_ isActive: Bool) {
        if isActive {
            activateVisibleWork()
        } else if !isOasisPrepared {
            deactivateVisibleWork()
        } else {
            visibleWorkTask?.cancel()
            visibleWorkTask = nil
            if !isEmbeddedVisible {
                deactivateVisiblePresentation()
            }
        }
    }

    private func handleActiveHumanChanged() {
        guard isOasisPrepared else { return }
        scheduleOasisRenderSnapshotRefresh(milliseconds: 40)
        loadCheckInData()
        if isEmbeddedActive {
            scheduleTodayCheckIn()
        }
    }

    private func handleAmbientMotionChanged(_ shouldAnimate: Bool) {
        if shouldAnimate {
            startAmbientMotionIfNeeded()
        } else {
            stopAmbientMotion()
        }
    }

    private func activateVisibleWork() {
        prepareVisibleShell()
        activateVisiblePresentation()
        scheduleVisibleWork(delayMilliseconds: hideToolbar ? 120 : 60)
    }

    private func activateVisiblePresentation() {
        prepareVisibleShell()
        isVisible = true
        startAmbientMotionIfNeeded()
    }

    private func prepareVisibleShell() {
        guard isOasisPrepared else { return }
        isVisible = shouldTreatEmbeddedAsVisible
        lastLevel = treeMgr.treeLevel
        refreshTreeHarvestSnapshot()
        justHarvested = !canHarvestTreeToday
        markVisibleStatePrepared()
        schedulePreparedVisualWork()
    }

    private func deactivateVisiblePresentation() {
        isVisible = false
        stopAmbientMotion()
    }

    private func deactivateVisibleWork() {
        isVisible = false
        isVisibleStatePrepared = false
        treeVisualEnergyOverride = nil
        coconutBalanceVisualOverride = nil
        preparedWorkTask?.cancel()
        preparedWorkTask = nil
        visibleWorkTask?.cancel()
        visibleWorkTask = nil
        treeCommandTask?.cancel()
        treeCommandTask = nil
        treeHarvestBuffer.commitTask?.cancel()
        treeHarvestBuffer.commitTask = nil
        treeHarvestBuffer.pendingCount = 0
        renderSnapshotTask?.cancel()
        renderSnapshotTask = nil
        critterNestCloseTask?.cancel()
        critterNestCloseTask = nil
        critterNestOpenTask?.cancel()
        critterNestOpenTask = nil
        injectionResetTask?.cancel()
        injectionResetTask = nil
        levelUpFeedbackTask?.cancel()
        levelUpFeedbackTask = nil
        particleCleanupTask?.cancel()
        particleCleanupTask = nil
        critterPulseCleanupTask?.cancel()
        critterPulseCleanupTask = nil
        critterOutcomeCleanupTask?.cancel()
        critterOutcomeCleanupTask = nil
        rescueBusyCleanupTask?.cancel()
        rescueBusyCleanupTask = nil
        stopAmbientMotion()
    }

    private func refreshOasisEnergyIfActive() {
        guard isEmbeddedActive, isVisibleStatePrepared else { return }
        scheduleVisibleWork(delayMilliseconds: 90)
        scheduleOasisRenderSnapshotRefresh(milliseconds: 120)
    }

    private func refreshFeaturedCritterLifecycleIfActive() {
        guard isEmbeddedActive else { return }
        scheduleVisibleWork(delayMilliseconds: 120)
    }

    private func injectTreeEnergyIfActive() {
        guard isEmbeddedActive else { return }
        injectTreeEnergy()
    }

    private func scheduleVisibleWork(delayMilliseconds: UInt64? = nil) {
        guard isEmbeddedActive else { return }
        visibleWorkTask?.cancel()
        let delay = delayMilliseconds ?? (hideToolbar ? 120 : 80)
        visibleWorkTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: delay) {
            guard isEmbeddedActive, isVisible else {
                visibleWorkTask = nil
                return
            }
            refreshVisibleState()
            visibleWorkTask = nil
        }
    }

    private func schedulePreparedVisualWork() {
        guard isOasisPrepared else { return }
        preparedWorkTask?.cancel()
        preparedWorkTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: hideToolbar ? 24 : 0) {
            guard isOasisPrepared else {
                preparedWorkTask = nil
                return
            }
            commandExecutor.refreshPreviewEnergy(treeManager: treeMgr, pets: pets, humans: humans, plants: plants)
            lastLevel = treeMgr.treeLevel
            loadCheckInData()
            rebuildOasisRenderSnapshots()
            markVisibleStatePrepared()
            preparedWorkTask = nil
        }
    }

    private func refreshVisibleState() {
        commandExecutor.refreshEnergy(treeManager: treeMgr, pets: pets, humans: humans, plants: plants)
        commandExecutor.refreshFeaturedCritterLifecycle(electronicPets)
        lastLevel = treeMgr.treeLevel
        loadCheckInData()
        scheduleTodayCheckIn()
        rebuildOasisRenderSnapshots()
        markVisibleStatePrepared()
    }

    private func markVisibleStatePrepared() {
        let wasPrepared = isVisibleStatePrepared
        isVisibleStatePrepared = true
        if wasPrepared {
            updateGlowMotion()
            updateHarvestBubbleMotion()
        } else {
            startAmbientMotionIfNeeded()
        }
    }

    private func scheduleOasisRenderSnapshotRefresh(milliseconds: UInt64 = 80) {
        guard isOasisPrepared else { return }
        renderSnapshotTask?.cancel()
        renderSnapshotTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: milliseconds) {
            guard isOasisPrepared else {
                renderSnapshotTask = nil
                return
            }
            rebuildOasisRenderSnapshots()
            renderSnapshotTask = nil
        }
    }

    private func rebuildOasisRenderSnapshots() {
        refreshTreeHarvestSnapshot()
        let nextActionSnapshot = commandExecutor.makeActionSnapshot(
            humans: humans,
            currentActiveHumanId: currentActiveHumanId,
            critterFragments: critterFragments
        )
        actionSnapshot = nextActionSnapshot
        bentoSnapshot = commandExecutor.makeBentoSnapshot(
            pets: pets,
            electronicPets: electronicPets,
            activeCoconutBalance: nextActionSnapshot.activeCoconutBalance
        )
        critterRenderSnapshots = commandExecutor.makeCritterSnapshots(electronicPets: electronicPets)
    }

    private func refreshTreeHarvestSnapshot() {
        canHarvestTreeToday = treeMgr.canHarvestToday
        treePassiveIncomeAmount = treeMgr.passiveIncomeAmount
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
            headerCoconutBalanceButton
        }
    }

    private var headerCoconutBalanceButton: some View {
        CoconutBalanceCapsule(
            balance: activeHumanCoconutBalance,
            showsDeltaAnimation: true,
            deltaAnimationContext: "oasis-\(currentActiveHumanId.isEmpty ? "global" : currentActiveHumanId)"
        ) {
            showingCoconutLog = true
        }
        .accessibilityLabel("椰子资产 \(activeHumanCoconutBalance)")
        .accessibilityHint("打开椰子历史")
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
                        level: treeVisualLevel.rawValue,
                        isInjecting: isInjecting,
                        growthProgress: treeVisualProgressToNextLevel,
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

                    if canHarvestTreeToday && !justHarvested {
                        stageHarvestButton
                            .padding(.bottom, 2)
                            .transition(.scale(scale: 0.94).combined(with: .opacity))
                    }

                    treeCritterEntryButton
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .offset(x: 78, y: -28)
                        .zIndex(5)
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
            refreshTreeHarvestSnapshot()
            justHarvested = !canHarvestTreeToday
            updateGlowMotion()
        }
        .onChange(of: treeVisualLevel) { oldLevel, newLevel in
            refreshTreeHarvestSnapshot()
            justHarvested = !canHarvestTreeToday
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
                            colors: [treeVisualLevel.glowColor.opacity(colorScheme == .light ? 0.22 : 0.32), .clear],
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
                        colors: [treeVisualLevel.glowColor.opacity(glowBreathing ? 0.30 : 0.10), .clear],
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
                .animation(GoMotion.quick, value: injectionPulseToken)
        }
        .allowsHitTesting(false)
    }

    private var stageTopHUD: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Lv.\(treeVisualLevel.rawValue)")
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(treeVisualLevel.displayName)
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
        let snapshot = critter.map { critterRenderSnapshot(for: $0).lifecycle }
        let tint = snapshot.map { critterLifecycleTint(for: $0.state) } ?? Color.goPrimary
        let statusIcon = snapshot.map { critterLifecycleIcon(for: $0.state) } ?? "lock.fill"
        let isLocked = critter == nil

        return Button {
            openCritterEntry()
        } label: {
            ZStack(alignment: .bottomTrailing) {
                if !isLocked {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    critterLifecycleAuraTint(snapshot?.state ?? .healthy).opacity(snapshot?.state == .healthy ? 0.42 : 0.68),
                                    critterLifecycleAuraTint(snapshot?.state ?? .healthy).opacity(0.18),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 6,
                                endRadius: 42
                            )
                        )
                        .frame(width: 82, height: 82)
                        .blur(radius: snapshot?.state == .healthy ? 8 : 12)
                        .shadow(color: critterLifecycleAuraTint(snapshot?.state ?? .healthy).opacity(snapshot?.state == .healthy ? 0.24 : 0.54), radius: 18, y: 0) // ui-v4: allow state aura for tree critter
                }

                OasisCritterIllustration(catalogId: catalogId, locked: isLocked, size: 60, critter: critter)
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
                Text(critter?.displayName(l) ?? l.tr(zh: "Lv.10", en: "Lv.10", de: "Lv.10"))
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.ohanaCardSurface.opacity(0.84), in: Capsule())
                    .offset(y: 13)
            }
            .frame(width: 82, height: 88)
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(critter == nil ? nextCritterGoalText : l.tr(zh: "电子宠物小窝", en: "Critter nest", de: "Critter-Nest"))
    }

    private var critterNestPopupOverlay: some View {
        GeometryReader { proxy in
            let progress = min(max(critterNestPopupProgress, 0), 1)
            ZStack {
                Color.black.opacity(0.34 * Double(progress)) // ui-v4: allow modal scrim
                    .ignoresSafeArea()
                    .onTapGesture {
                        closeCritterNest()
                    }

                OasisCritterCodexView(mode: .nest, isPopup: true) {
                    closeCritterNest()
                }
                .frame(
                    width: min(proxy.size.width - 20, 430),
                    height: min(proxy.size.height - 86, 760)
                )
                .padding(.horizontal, 10)
                .scaleEffect(0.92 + 0.08 * progress, anchor: .center)
                .offset(y: (1 - progress) * 24)
                .opacity(Double(progress))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(progress > 0.04)
        }
    }

    private var critterNestPopupOpenAnimation: Animation {
        shouldRunAmbientMotion ? GoMotion.heroExpand : GoMotion.reduced
    }

    private var critterNestPopupCloseAnimation: Animation {
        shouldRunAmbientMotion ? GoMotion.heroCollapse : GoMotion.reduced
    }

    private var critterNestPopupCloseDelay: Double {
        shouldRunAmbientMotion ? 0.54 : 0.12
    }

    private func closeCritterNest() {
        guard showCritterNest || critterNestPopupProgress > 0.001 else { return }
        withAnimation(critterNestPopupCloseAnimation) {
            critterNestPopupProgress = 0
        }
        critterNestCloseTask?.cancel()
        critterNestCloseTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: UInt64(critterNestPopupCloseDelay * 1000)) {
            if critterNestPopupProgress <= 0.001 {
                showCritterNest = false
            }
            critterNestCloseTask = nil
        }
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
                Text(treeVisualLevel == .lv10 ? l.tr(zh: "满级", en: "Max", de: "Max") : "\(treeVisualTotalEnergy)/\(treeVisualNextLevelThreshold)")
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Spacer()
                Text(treePassiveIncomeAmount > 0 ? "+\(treePassiveIncomeAmount)🥥/d" : "Lv.5 🥥")
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(Color.goPrimary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.ohanaControlFill)
                    Capsule()
                        .fill(LinearGradient(colors: [Color.goPrimary, Color.goTeal], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(8, geo.size.width * treeVisualProgressToNextLevel))
                        .contentTransition(.numericText())
                }
                .frame(height: 8)
                .animation(GoMotion.page, value: treeVisualProgressToNextLevel)
            }
            .frame(height: 8)
        }
    }

    private var stageInjectButton: some View {
        let canInject = canInjectTreeEnergy
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
                Text("+\(treePassiveIncomeAmount)")
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
            Text("Lv.\(treeVisualLevel.rawValue)")
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
        if treeVisualLevel == .lv10 {
            return l.tr(zh: "树冠已觉醒", en: "Tree awakened", de: "Baum erwacht")
        }
        return l.tr(zh: "下一颗升级椰子在树上成长", en: "Next upgrade coconut is growing", de: "Nächste Upgrade-Kokosnuss wächst")
    }

    private var nextCritterTargetCatalogId: String {
        let ownedIds = Set(electronicPets.filter { !$0.isArchived }.map(\.catalogId))
        return OasisUpgradeRewardCatalog.critters
            .sorted { $0.sourceLevel < $1.sourceLevel }
            .first { !ownedIds.contains($0.id) }?
            .id ?? OasisUpgradeRewardCatalog.firstCritterId
    }

    private func harvestTreeCoconut(_ idx: Int) {
        guard !harvestedCoconutIndices.contains(idx) else { return }
        OhanaFeedback.medium()
        treeHarvestBuffer.pendingCount += 1
        treeHarvestBuffer.commitTask?.cancel()
        treeHarvestBuffer.commitTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 760) {
            let amount = treeHarvestBuffer.pendingCount
            treeHarvestBuffer.pendingCount = 0
            commandExecutor.awardHarvestedTreeCoconuts(amount)
            rebuildOasisRenderSnapshots()
            treeHarvestBuffer.commitTask = nil
        }
    }

    private func harvestDailyTreeCoconuts() {
        guard canHarvestTreeToday else { return }
        let amount = treePassiveIncomeAmount
        guard amount > 0 else { return }
        OhanaFeedback.strong()
        withAnimation(GoMotion.feedback) {
            justHarvested = true
            canHarvestTreeToday = false
        }
        spawnEnergyParticles(count: 10)
        flyCoconut = false
        flyOpacity = 1
        withAnimation(GoMotion.fab.delay(0.05)) {
            flyCoconut = true
        }
        withAnimation(GoMotion.quick.delay(0.6)) {
            flyOpacity = 0
        }
        treeCommandTask?.cancel()
        treeCommandTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 80) {
            if commandExecutor.harvestDailyTreeCoconuts(treeManager: treeMgr) {
                rebuildOasisRenderSnapshots()
            }
            treeCommandTask = nil
        }
    }

    private func openCritterEntry() {
        guard !showCritterNest, critterNestPopupProgress <= 0.001 else { return }
        OhanaFeedback.light()
        critterNestCloseTask?.cancel()
        critterNestCloseTask = nil
        critterNestOpenTask?.cancel()
        critterNestOpenTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 40) {
            showCritterNest = true
            critterNestPopupProgress = max(critterNestPopupProgress, 0.001)
            withAnimation(critterNestPopupOpenAnimation) {
                critterNestPopupProgress = 1
            }
            critterNestOpenTask = nil
        }
    }

    private func injectTreeEnergy() {
        guard canInjectTreeEnergy else {
            OhanaFeedback.error()
            return
        }
        guard !isInjecting else { return }

        let beforeLevel = treeVisualLevel
        let beforeBalance = activeHumanCoconutBalance
        let targetBalance = max(0, beforeBalance - 10)
        let targetEnergy = treeMgr.totalEnergy + 10
        let targetLevel = OasisTreeManager.treeLevel(forTotalEnergy: targetEnergy)
        injectionPulseToken += 1
        let pulseToken = injectionPulseToken
        OhanaFeedback.light()
        withAnimation(GoMotion.feedback) {
            coconutBalanceVisualOverride = targetBalance
            actionSnapshot.activeCoconutBalance = targetBalance
            actionSnapshot.canInjectCoconuts = targetBalance >= 10
            bentoSnapshot.shopMetric = "🥥 \(targetBalance)"
        }
        withAnimation(GoMotion.hero) {
            treeVisualEnergyOverride = targetEnergy
        }
        withAnimation(GoMotion.tap) {
            isInjecting = true
        }
        spawnEnergyParticles(count: 8)

        treeCommandTask?.cancel()
        treeCommandTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 80) {
            let didInject = commandExecutor.injectTreeEnergy(treeManager: treeMgr)
            if didInject {
                if targetLevel != beforeLevel, treeVisualLevel == beforeLevel {
                    triggerLevelUpFeedback()
                }
                var transaction = Transaction(animation: nil)
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    rebuildOasisRenderSnapshots()
                    treeVisualEnergyOverride = nil
                    coconutBalanceVisualOverride = nil
                }
            } else {
                withAnimation(GoMotion.hero) {
                    treeVisualEnergyOverride = nil
                    coconutBalanceVisualOverride = nil
                    rebuildOasisRenderSnapshots()
                }
                withAnimation(GoMotion.tap) {
                    isInjecting = false
                }
                OhanaFeedback.error()
            }
            treeCommandTask = nil
        }

        injectionResetTask?.cancel()
        injectionResetTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 220) {
            guard injectionPulseToken == pulseToken else {
                injectionResetTask = nil
                return
            }
            withAnimation(GoMotion.tap) {
                isInjecting = false
            }
            injectionResetTask = nil
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
                        critterMilestonePill(level: 10, catalogId: OasisUpgradeRewardCatalog.firstCritterId)
                        critterMilestonePill(level: 20, catalogId: OasisUpgradeRewardCatalog.legendaryCritterId)
                    }
                } else if let critter = featuredCritter {
                    let snapshot = critterRenderSnapshot(for: critter)
                    let wish = snapshot.dailyWish
                    critterLifeStrip(critter, snapshot: snapshot.lifecycle)
                    if let wish {
                        critterWishStrip(wish, critter: critter, isCompleted: snapshot.isDailyWishCompleted)
                    }
                    if let lastCritterInteractionOutcome, lastCritterInteractionOutcome.success {
                        critterOutcomeStrip(lastCritterInteractionOutcome)
                    }
                    if snapshot.lifecycle.isRescuable {
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
                            cost: critterInteractionCostText(snapshot.feedCost),
                            enabled: snapshot.canFeed,
                            highlighted: !snapshot.isDailyWishCompleted && wish?.action == .feed
                        ) {
                            interact(with: critter, action: .feed)
                        }
                        critterNestAction(
                            icon: "sparkles",
                            title: l.tr(zh: "玩耍", en: "Play", de: "Spielen"),
                            cost: critterInteractionCostText(snapshot.playCost),
                            enabled: snapshot.canPlay,
                            highlighted: !snapshot.isDailyWishCompleted && wish?.action == .play
                        ) {
                            interact(with: critter, action: .play)
                        }
                        critterNestAction(
                            icon: "moon.fill",
                            title: l.tr(zh: "休息", en: "Rest", de: "Ruhen"),
                            cost: critterInteractionCostText(snapshot.restCost),
                            enabled: snapshot.canRest,
                            highlighted: !snapshot.isDailyWishCompleted && wish?.action == .rest
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
            OhanaFeedback.light()
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

    private func critterRenderSnapshot(for critter: OasisElectronicPet) -> OasisCritterRenderSnapshot {
        critterRenderSnapshots[critter.id] ?? OasisCritterRenderSnapshot.lightweight(for: critter)
    }

    private var nextCritterMilestoneLevel: Int {
        OasisUpgradeRewardCatalog.critter(id: nextCritterTargetCatalogId)?.sourceLevel ?? 10
    }

    private var nextCritterGoalText: String {
        guard let entry = OasisUpgradeRewardCatalog.critter(id: nextCritterTargetCatalogId) else {
            return l.tr(zh: "Lv.10 保底 Lumo", en: "Lv.10 guarantees Lumo", de: "Lv.10 garantiert Lumo")
        }
        if treeVisualLevel.rawValue < entry.sourceLevel {
            return l.tr(
                zh: "Lv.\(entry.sourceLevel) 保底 \(entry.nameZh)",
                en: "Lv.\(entry.sourceLevel) guarantees \(entry.nameEn)",
                de: "Lv.\(entry.sourceLevel) garantiert \(entry.nameDe)"
            )
        }
        return l.tr(zh: "\(entry.nameZh) 正在树上等待", en: "\(entry.nameEn) is waiting in the tree", de: "\(entry.nameDe) wartet im Baum")
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
        return min(1, max(0, CGFloat(treeVisualTotalEnergy) / CGFloat(targetEnergy)))
    }

    private func critterMilestonePill(level: Int, catalogId: String) -> some View {
        let entry = OasisUpgradeRewardCatalog.critter(id: catalogId)
        let isReached = treeVisualLevel.rawValue >= level
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

    private func critterInteractionCostText(_ cost: Int) -> String {
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

    private func critterLifecycleAuraTint(_ state: OasisCritterLifeState) -> Color {
        switch state {
        case .healthy:
            return Color.goPrimary
        case .dead:
            return Color.ohanaTertiaryText
        case .needsCare, .atRisk, .sick, .critical:
            return Color.goRed
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
        return HStack(spacing: 4) {
            Text("◇")
                .font(.system(size: 12, weight: .black))
            Text("\(actionSnapshot.critterFragmentTotal)")
                .font(.system(size: 12, weight: .black, design: .rounded))
        }
        .foregroundStyle(Color.goPrimary)
    }

    private func critterCompanionCard(_ critter: OasisElectronicPet) -> some View {
        let snapshot = critterRenderSnapshot(for: critter)
        let lifecycle = snapshot.lifecycle
        let isDead = lifecycle.state == .dead
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
                Text(lifecycle.state.name(l))
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(isDead ? Color.ohanaTertiaryText : Color.goPrimary)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 7) {
                if lifecycle.isRescuable {
                    critterActionButton(icon: "cross.case.fill", cost: l.tr(zh: "免费", en: "Free", de: "Gratis"), enabled: rescuingCritterId != critter.id) {
                        rescue(with: critter)
                    }
                } else {
                    critterActionButton(
                        icon: "carrot.fill",
                        cost: critterInteractionCostText(snapshot.feedCost),
                        enabled: snapshot.canFeed
                    ) {
                        interact(with: critter, action: .feed)
                    }
                    critterActionButton(
                        icon: "sparkles",
                        cost: critterInteractionCostText(snapshot.playCost),
                        enabled: snapshot.canPlay
                    ) {
                        interact(with: critter, action: .play)
                    }
                    critterActionButton(
                        icon: "star.fill",
                        cost: "\(snapshot.starFragmentsCost)◇",
                        enabled: snapshot.canUpgradeStar
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
        OhanaFeedback.medium()
        withAnimation(GoMotion.feedback) {
            openedUpgradeReward = nil
        }
        upgradeRewardTask?.cancel()
        upgradeRewardTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 220) {
            do {
                let result = try commandExecutor.openUpgradeCoconut(coconut)
                result.isMilestoneCritter ? OhanaFeedback.success() : OhanaFeedback.warning()
                withAnimation(GoMotion.fab) {
                    openedUpgradeReward = result
                    openingUpgradeCoconutId = nil
                }
                if result.isMilestoneCritter {
                    spawnEnergyParticles(count: 16)
                }
                rebuildOasisRenderSnapshots()
            } catch {
                OhanaFeedback.error()
                withAnimation(GoMotion.feedback) {
                    openingUpgradeCoconutId = nil
                }
            }
            upgradeRewardTask = nil
        }
    }

    private func interact(with critter: OasisElectronicPet, action: OasisCritterAction) {
        guard critterActionPulseId == nil else { return }
        OhanaFeedback.light()
        withAnimation(GoMotion.feedback) {
            critterActionPulseId = critter.id
        }
        critterCommandTask?.cancel()
        critterCommandTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 70) {
            do {
                let outcome = try commandExecutor.interact(with: critter, action: action)
                applyCritterInteractionOutcome(outcome, critter: critter)
            } catch {
                OhanaFeedback.error()
                withAnimation(GoMotion.feedback) {
                    critterActionPulseId = nil
                }
            }
            critterCommandTask = nil
        }
    }

    private func applyCritterInteractionOutcome(_ outcome: OasisCritterInteractionOutcome, critter: OasisElectronicPet) {
        if outcome.success {
            OhanaFeedback.light()
            withAnimation(GoMotion.feedback) {
                critterActionPulseId = critter.id
                lastCritterInteractionOutcome = outcome
            }
            critterPulseCleanupTask?.cancel()
            critterPulseCleanupTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 350) {
                withAnimation(GoMotion.feedback) {
                    critterActionPulseId = nil
                }
                critterPulseCleanupTask = nil
            }
            clearCritterInteractionOutcomeLater(outcome)
            rebuildOasisRenderSnapshots()
        } else {
            OhanaFeedback.warning()
            withAnimation(GoMotion.feedback) {
                critterActionPulseId = nil
            }
        }
    }

    private func rescue(with critter: OasisElectronicPet) {
        guard rescuingCritterId == nil else { return }
        rescuingCritterId = critter.id
        OhanaFeedback.light()
        withAnimation(GoMotion.feedback) {
            critterActionPulseId = critter.id
        }
        clearRescueBusyState(for: critter.id)

        critterCommandTask?.cancel()
        critterCommandTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 70) {
            do {
                let outcome = try commandExecutor.rescue(critter)
                applyCritterInteractionOutcome(outcome, critter: critter)
            } catch {
                OhanaFeedback.error()
                withAnimation(GoMotion.feedback) {
                    critterActionPulseId = nil
                }
            }
            critterCommandTask = nil
        }
    }

    private func clearRescueBusyState(for critterId: UUID) {
        rescueBusyCleanupTask?.cancel()
        rescueBusyCleanupTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 450) {
            guard rescuingCritterId == critterId else {
                rescueBusyCleanupTask = nil
                return
            }
            rescuingCritterId = nil
            rescueBusyCleanupTask = nil
        }
    }

    private func clearCritterInteractionOutcomeLater(_ outcome: OasisCritterInteractionOutcome) {
        critterOutcomeCleanupTask?.cancel()
        critterOutcomeCleanupTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 3_400) {
            guard lastCritterInteractionOutcome == outcome else {
                critterOutcomeCleanupTask = nil
                return
            }
            withAnimation(GoMotion.reduced) {
                lastCritterInteractionOutcome = nil
            }
            critterOutcomeCleanupTask = nil
        }
    }

    private func upgradeCritterStar(_ critter: OasisElectronicPet) {
        guard critterActionPulseId == nil else { return }
        OhanaFeedback.light()
        withAnimation(GoMotion.fab) {
            critterActionPulseId = critter.id
        }
        critterCommandTask?.cancel()
        critterCommandTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 70) {
            do {
                if try commandExecutor.upgradeStar(critter) {
                    OhanaFeedback.success()
                    withAnimation(GoMotion.feedback) {
                        critterActionPulseId = critter.id
                    }
                    rebuildOasisRenderSnapshots()
                } else {
                    OhanaFeedback.warning()
                }
                critterPulseCleanupTask?.cancel()
                critterPulseCleanupTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 400) {
                    withAnimation(GoMotion.feedback) {
                        critterActionPulseId = nil
                    }
                    critterPulseCleanupTask = nil
                }
            } catch {
                OhanaFeedback.error()
                withAnimation(GoMotion.feedback) {
                    critterActionPulseId = nil
                }
            }
            critterCommandTask = nil
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
                Text("能量 \(treeVisualTotalEnergy) · 下一级 \(treeVisualNextLevelThreshold)")
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
                        .frame(width: geo.size.width * treeVisualProgressToNextLevel, height: 8)
                        .shadow(color: Color.goPrimary.opacity(0.5), radius: 6, x: 0, y: 0) // ui-v4: allow Oasis progress shine
                        .animation(GoMotion.page, value: treeVisualProgressToNextLevel)
                }
            }
            .frame(height: 8)

            // Stats row
            HStack(spacing: 0) {
                progressStatCell(
                    value: treePassiveIncomeAmount > 0
                        ? "+\(treePassiveIncomeAmount)🥥/日"
                        : "Lv.5 解锁",
                    label: "被动收入",
                    color: treePassiveIncomeAmount > 0
                        ? Color.goPrimary
                        : Color.ohanaSecondaryText.opacity(0.6)
                )
                progressStatCell(
                    value: "\(humans.count + pets.count)成员",
                    label: "家庭贡献",
                    color: Color(hex: "5B6AFF")
                )
                progressStatCell(
                    value: "\(treeVisualTotalEnergy)",
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
        let canInject = canInjectTreeEnergy
        return Button {
            injectTreeEnergy()
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
        let currentLv = treeVisualLevel.rawValue
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
        applyCheckInSnapshot(commandExecutor.loadCheckInData(currentActiveHumanId: currentActiveHumanId))
    }

    private func triggerTodayCheckIn() {
        if let updatedDates = commandExecutor.triggerTodayCheckIn(
            currentActiveHumanId: currentActiveHumanId,
            checkedInDates: checkedInDates
        ) {
            checkedInDates = updatedDates
            rebuildOasisRenderSnapshots()
        }
    }

    private func scheduleTodayCheckIn() {
        checkInCommandTask?.cancel()
        checkInCommandTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 140) {
            guard isEmbeddedActive else {
                checkInCommandTask = nil
                return
            }
            triggerTodayCheckIn()
            checkInCommandTask = nil
        }
    }

    private func applyMakeup(date: String) {
        let snapshot = OasisCheckInSnapshot(
            checkedInDates: checkedInDates,
            makeupDates: makeupDates,
            makeupPackCount: makeupPackCount,
            lastClaimedMilestone: lastClaimedMilestone
        )
        guard let updated = commandExecutor.applyMakeup(
            date: date,
            currentActiveHumanId: currentActiveHumanId,
            snapshot: snapshot
        ) else { return }
        applyCheckInSnapshot(updated)
        OhanaFeedback.medium()
    }

    private func claimMilestone(_ days: Int, reward: Int, emoji: String) {
        lastClaimedMilestone = days
        OhanaFeedback.success()
        checkInCommandTask?.cancel()
        checkInCommandTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 70) {
            commandExecutor.claimMilestone(
                days: days,
                reward: reward,
                emoji: emoji,
                currentActiveHumanId: currentActiveHumanId
            )
            rebuildOasisRenderSnapshots()
            checkInCommandTask = nil
        }
    }

    private func applyCheckInSnapshot(_ snapshot: OasisCheckInSnapshot) {
        checkedInDates = snapshot.checkedInDates
        makeupDates = snapshot.makeupDates
        makeupPackCount = snapshot.makeupPackCount
        lastClaimedMilestone = snapshot.lastClaimedMilestone
    }

    // MARK: - Bento Grid

    private var oasisBentoGrid: some View {
        OasisBentoGridView(
            snapshot: bentoSnapshot,
            localization: l,
            onOpenShop: {
                coconutShopInitialCategory = .effect
                showCoconutShop = true
            },
            onOpenAchievements: {
                showAchievements = true
            },
            onOpenCritters: {
                showCritterCodex = true
            },
            onOpenGacha: {
                showGacha = true
            }
        )
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
        OhanaFeedback.success()
        spawnEnergyParticles(count: 22)
        withAnimation(GoMotion.fab) {
            levelUpPulse = true
            levelUpBadgeVisible = true
        }
        levelUpFeedbackTask?.cancel()
        levelUpFeedbackTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 700) {
            withAnimation(GoMotion.hero) {
                levelUpPulse = false
            }
            levelUpFeedbackTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 650) {
                withAnimation(GoMotion.quick) {
                    levelUpBadgeVisible = false
                }
                levelUpFeedbackTask = nil
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
        particleCleanupTask?.cancel()
        particleCleanupTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 1_750) {
            energyParticles.removeAll()
            particleCleanupTask = nil
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
        .ohanaSheetPagePresentation() // ui-v4: allow rules reference sheet
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
