//
//  OasisRewardView.swift
//  Ohana
//
//  绿洲圣地 — 生命之树动态进化 + 注入能量 + Bento 功能区
//

import SwiftUI
import SwiftData

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
    let makeupConfirmationConfirmTitle: String
    let makeupConfirmationCancelTitle: String
    let makeupConfirmationBinding: Binding<Bool>
    @Binding var confirmationRoute: OasisConfirmationRoute?
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
    let onOpenSheet: (OasisSheetRoute) -> Void

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
            .onChange(of: rulesTrigger) { _, _ in onOpenSheet(.coconutRules) }
            .onChange(of: inventoryTrigger) { _, _ in onOpenSheet(.inventory) }
            .onChange(of: injectEnergyTrigger) { _, _ in onInjectTreeEnergy() }
            .onChange(of: isEmbeddedPrepared) { _, isPrepared in onEmbeddedPreparedChanged(isPrepared) }
            .onChange(of: isEmbeddedVisible) { _, isVisible in onEmbeddedVisibleChanged(isVisible) }
            .onChange(of: isEmbeddedActive) { _, isActive in onEmbeddedActiveChanged(isActive) }
    }

    private var makeupConfirmationModifier: some ViewModifier {
        OasisRewardMakeupConfirmationModifier(
            makeupConfirmationTitle: makeupConfirmationTitle,
            confirmTitle: makeupConfirmationConfirmTitle,
            cancelTitle: makeupConfirmationCancelTitle,
            makeupConfirmationBinding: makeupConfirmationBinding,
            confirmationRoute: $confirmationRoute,
            onApplyMakeup: onApplyMakeup
        )
    }
}

private struct OasisRewardMakeupConfirmationModifier: ViewModifier {
    let makeupConfirmationTitle: String
    let confirmTitle: String
    let cancelTitle: String
    let makeupConfirmationBinding: Binding<Bool>
    @Binding var confirmationRoute: OasisConfirmationRoute?
    let onApplyMakeup: (String) -> Void

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                makeupConfirmationTitle,
                isPresented: makeupConfirmationBinding,
                titleVisibility: .visible
            ) {
                Button(confirmTitle) {
                    if let date = confirmationRoute?.makeupDate {
                        onApplyMakeup(date)
                    }
                    confirmationRoute = nil
                }
                Button(cancelTitle, role: .cancel) {
                    confirmationRoute = nil
                }
            }
    }
}

private final class OasisTreeHarvestBuffer {
    var pendingIndices: Set<Int> = []
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
    var onPresentCoconutLog: ((CoconutLogSubject?) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var liveDataStore = OasisRewardLiveDataStore()

    @State private var treeScale: CGFloat   = 1.0
    @State private var treeGlow: CGFloat    = 0.4
    @State private var activeSheetRoute: OasisSheetRoute?
    @State private var activeFullScreenRoute: OasisFullScreenRoute?
    @State private var activeOverlayRoute: OasisOverlayRoute?
    @State private var confirmationRoute: OasisConfirmationRoute?
    @State private var showCritterNest      = false
    @State private var critterNestPopupProgress: CGFloat = 0
    @State private var energyParticles: [EnergyParticle] = []
    // 模块六：打卡日历
    @State private var checkedInDates: Set<String> = []   // "yyyy-MM-dd" 格式
    @State private var makeupPackCount: Int = 0            // 补签包数量
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
    @State private var treeInjectionProgress: CGFloat = 0
    @State private var treeInjectionBoost: CGFloat = 0.026
    @State private var injectionPulseToken = 0
    @State private var levelUpPulse         = false
    @State private var levelUpBadgeVisible  = false
    @State private var openingUpgradeCoconutId: UUID?
    @State private var critterActionPulseId: UUID?
    @State private var lastCritterInteractionOutcome: OasisCritterInteractionOutcome?
    @State private var rescuingCritterId: UUID?
    // 任务7：环境光晕 + 树上每日椰子
    @State private var glowBreathing: Bool  = false
    @State private var dailyTreeCoconutCount = 0
    @State private var harvestedCoconutIndices: Set<Int> = []
    @State private var treeVisualEnergyOverride: Int?
    @State private var coconutBalanceVisualOverride: Int?
    @State private var isVisible = false
    @State private var isVisibleStatePrepared = false
    @State private var actionSnapshot = OasisRewardActionSnapshot()
    @State private var bentoSnapshot = OasisBentoSnapshot()
    @State private var critterRenderSnapshots: [UUID: OasisCritterRenderSnapshot] = [:]
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
    private var liveData: OasisRewardLiveDataSnapshot { liveDataStore.snapshot }
    private var pets: [Pet] { liveData.pets }
    private var humans: [Human] { liveData.humans }
    private var plants: [Plant] { liveData.plants }
    private var upgradeCoconuts: [OasisUpgradeCoconut] { liveData.upgradeCoconuts }
    private var electronicPets: [OasisElectronicPet] { liveData.electronicPets }
    private var critterFragments: [OasisCritterFragmentBalance] { liveData.critterFragments }
    private var commandExecutor: OasisRewardCommandExecutor {
        OasisRewardCommandExecutor(context: modelContext)
    }

    private var openedUpgradeReward: OasisOpenedUpgradeReward? {
        activeOverlayRoute?.upgradeReward
    }

    private func openSheet(_ route: OasisSheetRoute) {
        activeSheetRoute = route
    }

    private func openFullScreen(_ route: OasisFullScreenRoute) {
        activeFullScreenRoute = route
    }

    private func presentUpgradeReward(_ reward: OasisOpenedUpgradeReward) {
        activeOverlayRoute = .upgradeReward(reward: reward)
    }

    private func dismissUpgradeReward() {
        activeOverlayRoute = nil
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
        actionSnapshot.canInjectCoconuts ?? (activeHumanCoconutBalance >= 80)
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

    private var interactionMotionBudget: OhanaMotionBudget {
        workloadPolicy.interactionMotionBudget(
            isVisible: (isVisible || shouldTreatEmbeddedAsVisible) && isOasisPrepared
        )
    }

    private var isOasisPrepared: Bool {
        isEmbeddedPrepared || isEmbeddedVisible || isEmbeddedActive
    }

    private var shouldTreatEmbeddedAsVisible: Bool {
        isEmbeddedVisible || isEmbeddedActive
    }

    private var treeInjectionVisualScale: CGFloat {
        1 + treeInjectionProgress * treeInjectionBoost
    }

    private var makeupConfirmationTitle: String {
        confirmationRoute?.makeupDate.map {
            l.tr(zh: "补签 \($0)？", en: "Make up \($0)?", de: "\($0) nachtragen?")
        } ?? ""
    }

    private var makeupConfirmationConfirmTitle: String {
        l.tr(
            zh: "消耗 1 个补签包确认补签",
            en: "Use 1 makeup pack",
            de: "1 Nachtragspaket nutzen"
        )
    }

    private var makeupConfirmationCancelTitle: String {
        l.tr(zh: "取消", en: "Cancel", de: "Abbrechen")
    }

    private var makeupConfirmationBinding: Binding<Bool> {
        Binding(
            get: { confirmationRoute != nil },
            set: { newValue in
                if !newValue {
                    confirmationRoute = nil
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
                .font(OhanaFont.body(.semibold))
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
                        makeupConfirmationConfirmTitle: makeupConfirmationConfirmTitle,
                        makeupConfirmationCancelTitle: makeupConfirmationCancelTitle,
                        makeupConfirmationBinding: makeupConfirmationBinding,
                        confirmationRoute: $confirmationRoute,
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
                        onApplyMakeup: applyMakeup,
                        onOpenSheet: openSheet
                    )
                )
        )
    }

    private var oasisPresentedContent: AnyView {
        AnyView(
            oasisRootContent
                .modifier(
                    OasisRewardPresentationModifier(
                        sheetRoute: $activeSheetRoute,
                        fullScreenRoute: $activeFullScreenRoute,
                        pets: pets,
                        onPresentCoconutLog: onPresentCoconutLog
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
            Image(systemName: "sparkles") // a11y: allow decorative energy particle
                .font(OhanaFont.title3(.black))
                .foregroundStyle(Color.goPrimary)
                .offset(x: p.offsetX, y: p.offsetY)
                .opacity(p.opacity)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
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
            refreshLiveDataSnapshot()
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
        isInjecting = false
        treeInjectionProgress = 0
        treeInjectionBoost = 0.026
        preparedWorkTask?.cancel()
        preparedWorkTask = nil
        visibleWorkTask?.cancel()
        visibleWorkTask = nil
        treeCommandTask?.cancel()
        treeCommandTask = nil
        treeHarvestBuffer.commitTask?.cancel()
        commitPendingTreeHarvests(reconcile: false)
        treeHarvestBuffer.commitTask = nil
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
        liveDataStore.reset()
        stopAmbientMotion()
    }

    private func refreshLiveDataSnapshot() {
        liveDataStore.refresh(context: modelContext)
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
            refreshLiveDataSnapshot()
            commandExecutor.refreshPreviewEnergy(treeManager: treeMgr, pets: pets, humans: humans, plants: plants)
            lastLevel = treeMgr.treeLevel
            loadCheckInData()
            rebuildOasisRenderSnapshots()
            markVisibleStatePrepared()
            preparedWorkTask = nil
        }
    }

    private func refreshVisibleState() {
        refreshLiveDataSnapshot()
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
        refreshLiveDataSnapshot()
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
        critterRenderSnapshots = commandExecutor.makeCritterSnapshots(
            electronicPets: electronicPets,
            fragments: critterFragments
        )
    }

    private func refreshTreeHarvestSnapshot() {
        let capacity = BeautifulCoconutTree.coconutCapacity(for: treeVisualLevel.rawValue)
        let snapshot = treeMgr.dailyTreeCoconutSnapshot(maxCoconutCount: capacity)
        dailyTreeCoconutCount = snapshot.coconutCount
        harvestedCoconutIndices = snapshot.harvestedIndices.union(treeHarvestBuffer.pendingIndices)
        treePassiveIncomeAmount = snapshot.coconutCount
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
            .accessibilityLabel(l.tr(zh: "关闭", en: "Close", de: "Schließen"))

            Spacer()

            oasisToolbarButton(systemName: "info.circle") {
                openSheet(.coconutRules)
            }
            .accessibilityLabel(l.tr(zh: "椰子规则", en: "Coconut rules", de: "Kokosnuss-Regeln"))
            oasisToolbarButton(systemName: "shippingbox.fill") {
                openSheet(.inventory)
            }
            .accessibilityLabel(l.tr(zh: "库存", en: "Inventory", de: "Inventar"))
        }
    }

    private var oasisHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(l.tr(zh: "OASIS · 绿洲", en: "OASIS", de: "OASE"))
                    .font(OhanaFont.caption(.semibold))
                    .kerning(1.2)
                    .foregroundStyle(Color.ohanaSecondaryText)
                Text(l.tr(zh: "生命之树", en: "Life Tree", de: "Lebensbaum"))
                    .font(OhanaFont.title(.black))
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
            presentCoconutLog()
        }
        .accessibilityLabel(l.tr(
            zh: "椰子资产 \(activeHumanCoconutBalance)",
            en: "Coconut balance \(activeHumanCoconutBalance)",
            de: "Kokosnuss-Guthaben \(activeHumanCoconutBalance)"
        ))
        .accessibilityHint(l.tr(zh: "打开椰子历史", en: "Open coconut history", de: "Kokosnuss-Verlauf öffnen"))
    }

    private func presentCoconutLog() {
        onPresentCoconutLog?(nil)
    }

    // MARK: - Life Tree Stage

    private var treeSceneCard: some View {
        let stageShape = RoundedRectangle(cornerRadius: 34, style: .continuous)
        return ZStack {
            stageBackground(shape: stageShape)

            stageStars

            Circle()
                .fill(Color.goYellow)
                .frame(width: 26, height: 26) // a11y: allow decorative celestial dot
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
                        dailyCoconutCount: dailyTreeCoconutCount,
                        allowsAmbientMotion: shouldRunAmbientMotion,
                        harvestedCoconuts: harvestedCoconutIndices,
                        onHarvest: { harvestTreeCoconut($0) }
                    )
                    .shadow(color: Color.goPrimary.opacity(glowBreathing ? 0.42 : 0.16), radius: glowBreathing ? 22 : 10, x: 0, y: 0) // ui-v4: allow Oasis tree focus glow
                    .scaleEffect(treeScale * treeInjectionVisualScale)
                    .animation(GoMotion.hero, value: treeScale)
                    .animation(interactionMotionBudget.allowsMotion ? GoMotion.feedback : GoMotion.reduced, value: treeInjectionProgress)
                    .frame(height: 300)
                    .padding(.bottom, 16)

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
                OasisStageOpenedRewardCard(
                    reward: reward,
                    localization: l,
                    onClose: {
                        withAnimation(GoMotion.feedback) {
                            dismissUpgradeReward()
                        }
                    }
                )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .padding(.horizontal, 22)
                    .transition(.scale(scale: 0.94).combined(with: .opacity))
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
            updateGlowMotion()
        }
        .onChange(of: treeVisualLevel) { oldLevel, newLevel in
            refreshTreeHarvestSnapshot()
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
                    ? .easeInOut(duration: 2.4).repeatForever(autoreverses: true) // runtime-guardrail: allow AppWorkloadPolicy-gated stage glow; smoothness: allow visible-only ambient tree glow
                    : nil,
                    value: glowBreathing
                )

            Circle()
                .stroke(Color.goPrimary.opacity(glowBreathing ? 0.18 : 0.05), lineWidth: 2)
                .frame(width: 250, height: 250)
                .blur(radius: glowBreathing ? 7 : 2)
                .animation(
                    shouldRunAmbientMotion
                    ? .easeInOut(duration: 2.4).repeatForever(autoreverses: true) // runtime-guardrail: allow AppWorkloadPolicy-gated stage ring; smoothness: allow visible-only ambient tree ring
                    : nil,
                    value: glowBreathing
                )
        }
        .offset(y: -32)
        .allowsHitTesting(false)
    }

    private var treeEnergyBeam: some View {
        let progress = max(0, min(1, treeInjectionProgress))
        return VStack(spacing: 0) {
            Spacer()
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color.goPrimary.opacity(0), Color.goPrimary.opacity(0.85), Color.goTeal.opacity(0)],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(width: 2 + 7 * progress, height: 52 + 168 * progress)
                .blur(radius: 10 - 5 * progress)
                .opacity(0.9 * Double(progress))
                .offset(y: -18 - 120 * progress)
                .animation(
                    interactionMotionBudget.allowsMotion ? GoMotion.feedback : GoMotion.reduced,
                    value: treeInjectionProgress
                )
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
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(snapshot?.state == .critical ? Color.arkInk : Color.ohanaPrimaryActionText)
                    .frame(width: 22, height: 22) // a11y: allow decorative critter status badge
                    .background(tint, in: Circle())
                    .overlay(Circle().strokeBorder(Color.ohanaCardSurface.opacity(0.84), lineWidth: 1))
                    .offset(x: 3, y: 3)
                    .accessibilityHidden(true)
            }
            .overlay(alignment: .bottom) {
                Text(critter?.displayName(l) ?? l.tr(zh: "Lv.10", en: "Lv.10", de: "Lv.10"))
                    .font(OhanaFont.caption2(.black))
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

                OasisCritterCodexRouteContainer(
                    mode: .nest,
                    isPopup: true,
                    onClose: {
                        closeCritterNest()
                    },
                    onPresentCoconutLog: onPresentCoconutLog ?? { _ in }
                )
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
                    OasisRewardKindIcon(reward: reward, size: 13)
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
                    Image(systemName: "sparkles") // a11y: allow decorative empty-state sparkle
                        .accessibilityHidden(true)
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
                        .frame(width: 42, height: 42) // a11y: allow noninteractive overflow count chip
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
                    .font(OhanaFont.metric(size: 28))
                    .rotationEffect(.degrees(isOpening ? -12 : 0))
                    .scaleEffect(isOpening ? 1.14 : 1)
                    .frame(width: 48, height: 48)
                    .background(isMilestone ? Color.goPrimary.opacity(0.18) : Color.ohanaControlFill, in: Circle())
                Image(systemName: "hammer.fill") // a11y: allow decorative button badge
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .frame(width: 19, height: 19) // a11y: allow decorative button badge
                    .background(Color.goPrimary, in: Circle())
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .animation(GoMotion.feedback, value: isOpening)
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
                Image(systemName: "bolt.fill") // a11y: allow decorative action icon paired with label
                    .font(OhanaFont.subheadline(.black))
                    .accessibilityHidden(true)
                Text(l.tr(zh: "注入 +20XP", en: "Infuse +20XP", de: "+20XP einspeisen"))
                    .font(OhanaFont.callout(.black))
                Text("-80🥥")
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

    private var stageLevelUpBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles") // a11y: allow decorative level badge icon
                .font(OhanaFont.footnote(.black))
                .accessibilityHidden(true)
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
        guard idx >= 0,
              idx < dailyTreeCoconutCount,
              !harvestedCoconutIndices.contains(idx),
              !treeHarvestBuffer.pendingIndices.contains(idx) else { return }
        OhanaFeedback.medium()
        withAnimation(GoMotion.feedback) {
            _ = harvestedCoconutIndices.insert(idx)
        }
        applyCoconutBalanceVisualDelta(1)
        treeHarvestBuffer.pendingIndices.insert(idx)
        treeHarvestBuffer.commitTask?.cancel()
        treeHarvestBuffer.commitTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 120) {
            commitPendingTreeHarvests()
        }
    }

    private func commitPendingTreeHarvests(reconcile: Bool = true) {
        let pendingIndices = treeHarvestBuffer.pendingIndices
        guard !pendingIndices.isEmpty else {
            treeHarvestBuffer.commitTask = nil
            return
        }

        let capacity = BeautifulCoconutTree.coconutCapacity(for: treeVisualLevel.rawValue)
        var awardedCount = 0
        var latestSnapshot: OasisDailyTreeCoconutSnapshot?
        for index in pendingIndices.sorted() {
            let before = treeMgr.dailyTreeCoconutSnapshot(maxCoconutCount: capacity)
            guard !before.harvestedIndices.contains(index) else {
                latestSnapshot = before
                continue
            }
            let after = treeMgr.markDailyTreeCoconutHarvested(index, maxCoconutCount: capacity)
            latestSnapshot = after
            if after.harvestedIndices.contains(index) {
                awardedCount += 1
            }
        }

        treeHarvestBuffer.pendingIndices.removeAll()
        if let latestSnapshot {
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                harvestedCoconutIndices = latestSnapshot.harvestedIndices
            }
        }
        if awardedCount > 0 {
            commandExecutor.awardHarvestedTreeCoconuts(awardedCount)
        }
        if reconcile {
            reconcileCoconutBalanceAfterCommand()
        }
        treeHarvestBuffer.commitTask = nil
    }

    private func applyCoconutBalanceVisualDelta(_ amount: Int) {
        guard amount != 0 else { return }
        let targetBalance = max(0, activeHumanCoconutBalance + amount)
        withAnimation(GoMotion.feedback) {
            coconutBalanceVisualOverride = targetBalance
            actionSnapshot.activeCoconutBalance = targetBalance
            actionSnapshot.canInjectCoconuts = targetBalance >= 80
            bentoSnapshot.shopMetric = "\(targetBalance)"
        }
    }

    private func reconcileCoconutBalanceAfterCommand() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            rebuildOasisRenderSnapshots()
            coconutBalanceVisualOverride = nil
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

        let motionBudget = interactionMotionBudget
        let visualAnimation = motionBudget.allowsMotion ? GoMotion.feedback : GoMotion.reduced
        let commandDelay: UInt64 = motionBudget.usesFullMotion ? 280 : 120
        let resetDelay: UInt64 = motionBudget.usesFullMotion ? 230 : 120
        let thawDelay: UInt64 = motionBudget.usesFullMotion ? 120 : 48
        let beforeLevel = treeVisualLevel
        let beforeBalance = activeHumanCoconutBalance
        let targetBalance = max(0, beforeBalance - 80)
        let targetEnergy = treeMgr.totalEnergy + 20
        let targetLevel = OasisTreeManager.treeLevel(forTotalEnergy: targetEnergy)
        let isLevelUp = targetLevel.rawValue > beforeLevel.rawValue
        let pulseBoost: CGFloat = motionBudget.usesFullMotion ? (isLevelUp ? 0.045 : 0.026) : 0.01
        injectionPulseToken += 1
        let pulseToken = injectionPulseToken
        OhanaFeedback.light()
        withAnimation(visualAnimation) {
            coconutBalanceVisualOverride = targetBalance
            actionSnapshot.activeCoconutBalance = targetBalance
            actionSnapshot.canInjectCoconuts = targetBalance >= 80
            bentoSnapshot.shopMetric = "\(targetBalance)"
            treeVisualEnergyOverride = targetEnergy
            isInjecting = true
            treeInjectionBoost = pulseBoost
            treeInjectionProgress = 1
        }
        if isLevelUp {
            triggerLevelUpFeedback()
        }

        treeCommandTask?.cancel()
        treeCommandTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: commandDelay) {
            let didInject = commandExecutor.injectTreeEnergy(treeManager: treeMgr)
            if didInject {
                treeCommandTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: thawDelay) {
                    var transaction = Transaction(animation: nil)
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        rebuildOasisRenderSnapshots()
                        isInjecting = false
                        treeVisualEnergyOverride = nil
                        coconutBalanceVisualOverride = nil
                    }
                    treeCommandTask = nil
                }
            } else {
                injectionResetTask?.cancel()
                injectionResetTask = nil
                withAnimation(visualAnimation) {
                    isInjecting = false
                    treeInjectionProgress = 0
                    treeInjectionBoost = 0.026
                    treeVisualEnergyOverride = nil
                    coconutBalanceVisualOverride = nil
                }
                rebuildOasisRenderSnapshots()
                OhanaFeedback.error()
                treeCommandTask = nil
            }
        }

        injectionResetTask?.cancel()
        injectionResetTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: resetDelay) {
            guard injectionPulseToken == pulseToken else {
                injectionResetTask = nil
                return
            }
            withAnimation(visualAnimation) {
                treeInjectionProgress = 0
            }
            injectionResetTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 120) {
                guard injectionPulseToken == pulseToken else {
                    injectionResetTask = nil
                    return
                }
                treeInjectionBoost = 0.026
                injectionResetTask = nil
            }
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
                                    .font(OhanaFont.title3(.black))
                                    .foregroundStyle(Color.ohanaPrimaryText)
                                Text(l.tr(zh: critter.rarity.zh, en: critter.rarity.en, de: critter.rarity.de))
                                    .font(OhanaFont.caption2(.black))
                                    .foregroundStyle(Color.ohanaPrimaryActionText)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(critterRarityColor(critter.rarity), in: Capsule())
                            }
                            Text(critter.displayName(l))
                                .font(OhanaFont.title(.black))
                                .foregroundStyle(Color.goPrimary)
                                .contentTransition(.numericText())
                            HStack(spacing: 8) {
                                critterQuickMetric(icon: "fork.knife", value: "\(critter.hunger)")
                                critterQuickMetric(icon: "face.smiling", value: "\(critter.mood)")
                                critterQuickMetric(icon: "cross.case.fill", value: "\(critter.health)")
                                critterQuickMetric(icon: "heart.fill", value: "B\(critterRenderSnapshot(for: critter).bondLevel)")
                                critterQuickMetric(icon: "star.fill", value: "\(critter.starLevel)")
                            }
                        }
                    } else {
                        OasisCritterIllustration(catalogId: OasisUpgradeRewardCatalog.firstCritterId, locked: true, size: 104)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(l.tr(zh: "升级生命树，唤醒电子宠物", en: "Level the tree. Wake critters.", de: "Baum leveln. Critter wecken."))
                                .font(OhanaFont.title2(.black))
                                .foregroundStyle(Color.ohanaPrimaryText)
                                .lineLimit(2)
                            Text(nextCritterGoalText)
                                .font(OhanaFont.footnote(.black))
                                .foregroundStyle(Color.goPrimary)
                            milestoneProgressBar
                        }
                    }

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.right") // a11y: allow decorative disclosure cue
                        .font(OhanaFont.subheadline(.black))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .accessibilityHidden(true)
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
            openSheet(.critterCodex)
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
                    .font(OhanaFont.footnote(.black))
                    .foregroundStyle(isReached ? Color.goPrimary : Color.ohanaPrimaryText)
                Text(entry?.name(l) ?? "")
                    .font(OhanaFont.caption2(.bold))
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
                .font(OhanaFont.caption2(.black))
                .accessibilityHidden(true)
            Text(value)
                .font(OhanaFont.caption2(.black))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .foregroundStyle(Color.ohanaSecondaryText)
    }

    private func critterLifeStrip(_ critter: OasisElectronicPet, snapshot: OasisCritterLifecycleSnapshot) -> some View {
        HStack(spacing: 9) {
            Image(systemName: critterLifecycleIcon(for: snapshot.state))
                .font(OhanaFont.footnote(.black))
                .foregroundStyle(snapshot.state == .critical ? Color.arkInk : Color.ohanaPrimaryActionText)
                .frame(width: 32, height: 32) // a11y: allow decorative lifecycle badge paired with state text
                .background(critterLifecycleTint(for: snapshot.state), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.state.name(l))
                    .font(OhanaFont.footnote(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                Text(l.text(critterRenderSnapshot(for: critter).prompt))
                    .font(OhanaFont.caption2(.bold))
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
                .font(OhanaFont.footnote(.black))
                .foregroundStyle(isCompleted ? Color.arkInk : Color.ohanaPrimaryActionText)
                .frame(width: 32, height: 32) // a11y: allow decorative wish badge paired with text
                .background(isCompleted ? Color.goPrimary : critterRarityColor(critter.rarity), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(isCompleted ? l.tr(zh: "今日小愿望完成", en: "Tiny wish complete", de: "Kleiner Wunsch erfüllt") : wish.title(l))
                    .font(OhanaFont.footnote(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                Text(isCompleted ? l.tr(zh: "明天还有新的心愿。", en: "New wish tomorrow.", de: "Morgen gibt es einen neuen Wunsch.") : wish.rewardText(l))
                    .font(OhanaFont.caption2(.bold))
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
                .font(OhanaFont.caption(.black))
                .foregroundStyle(outcome.completedDailyWish ? Color.arkInk : Color.goPrimary)
                .frame(width: 28, height: 28) // a11y: allow decorative outcome badge paired with text
                .background(outcome.completedDailyWish ? Color.goYellow : Color.ohanaControlFill, in: Circle())
                .accessibilityHidden(true)
            Text(outcome.message(l))
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(2)
            Spacer(minLength: 0)
            let reward = outcome.rewardText(l)
            if !reward.isEmpty {
                Text(reward)
                    .font(OhanaFont.caption2(.black))
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
                    .font(OhanaFont.footnote(.black))
                Text(title)
                    .font(OhanaFont.caption(.black))
                Text(cost)
                    .font(OhanaFont.caption2(.black))
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
                OasisOpenedUpgradeRewardDockCard(
                    reward: reward,
                    localization: l,
                    onClose: {
                        withAnimation(GoMotion.feedback) {
                            dismissUpgradeReward()
                        }
                    }
                )
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
            }

            if !pendingUpgradeCoconuts.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles") // a11y: allow decorative section icon
                            .font(OhanaFont.callout(.black))
                            .foregroundStyle(Color.goPrimary)
                            .accessibilityHidden(true)
                        Text(l.tr(zh: "升级椰子", en: "Upgrade Coconuts", de: "Upgrade-Kokosnüsse"))
                            .font(OhanaFont.headline(.black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Spacer()
                        Text("\(pendingUpgradeCoconuts.count)")
                            .font(OhanaFont.footnote(.black))
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
                        .font(OhanaFont.metric(size: 26))
                        .rotationEffect(.degrees(isOpening ? -12 : 0))
                        .scaleEffect(isOpening ? 1.16 : 1)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Lv.\(coconut.level) · \(coconut.title(l))")
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(isMilestone
                         ? l.tr(zh: "里程碑保底", en: "Milestone guaranteed", de: "Meilenstein garantiert")
                        : coconut.description(l))
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(isMilestone ? Color.goPrimary : Color.ohanaSecondaryText)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "hammer.fill") // a11y: allow decorative row action icon
                    .font(OhanaFont.subheadline(.black))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .frame(width: 44, height: 44)
                    .background(Color.goPrimary, in: Circle())
                    .accessibilityHidden(true)
            }
            .padding(10)
            .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("\(coconut.title(l)) \(l.tr(zh: "敲开", en: "Open", de: "Öffnen"))")
    }

    private var critterCompanionStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "pawprint.fill") // a11y: allow decorative section icon
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.goPrimary)
                    .accessibilityHidden(true)
                Text(l.tr(zh: "电子宠物", en: "Critters", de: "Critter"))
                    .font(OhanaFont.headline(.black))
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
                .font(OhanaFont.footnote(.black))
            Text("\(actionSnapshot.critterFragmentTotal)")
                .font(OhanaFont.footnote(.black))
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
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(l.tr(zh: critter.rarity.zh, en: critter.rarity.en, de: critter.rarity.de))
                        .font(OhanaFont.caption2(.black))
                        .foregroundStyle(Color.ohanaPrimaryActionText)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.goPrimary, in: Capsule())
                }

                HStack(spacing: 6) {
                    critterMeter(value: critter.hunger, icon: "fork.knife")
                    critterMeter(value: critter.mood, icon: "face.smiling")
                    critterMeter(value: critter.health, icon: "cross.case.fill")
                    critterMeter(value: snapshot.bondProgress, icon: "heart.fill")
                }
                Text(lifecycle.state.name(l))
                    .font(OhanaFont.caption2(.black))
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
                .font(OhanaFont.caption2(.bold))
                .accessibilityHidden(true)
            Text("\(max(0, min(100, value)))")
                .font(OhanaFont.caption2(.black))
                .contentTransition(.numericText())
        }
        .foregroundStyle(Color.ohanaSecondaryText)
    }

    private func critterActionButton(icon: String, cost: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Image(systemName: icon)
                    .font(OhanaFont.footnote(.black))
                    .accessibilityHidden(true)
                Text(cost)
                    .font(OhanaFont.caption2(.black))
            }
            .foregroundStyle(Color.ohanaPrimaryActionText)
            .frame(width: 44, height: 44)
            .background(enabled ? Color.goPrimary : Color.ohanaControlFill, in: Circle())
            .opacity(enabled ? 1 : 0.5)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!enabled)
    }

    private func openUpgradeCoconut(_ coconut: OasisUpgradeCoconut) {
        guard openingUpgradeCoconutId == nil else { return }
        OhanaFeedback.medium()
        withAnimation(GoMotion.feedback) {
            openingUpgradeCoconutId = coconut.id
            dismissUpgradeReward()
        }
        upgradeRewardTask?.cancel()
        upgradeRewardTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 80) {
            do {
                let result = try commandExecutor.openUpgradeCoconut(coconut)
                result.isMilestoneCritter ? OhanaFeedback.success() : OhanaFeedback.warning()
                withAnimation(GoMotion.fab) {
                    presentUpgradeReward(result)
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
        OasisProgressCard(
            totalEnergy: treeVisualTotalEnergy,
            nextLevelThreshold: treeVisualNextLevelThreshold,
            progressToNextLevel: CGFloat(treeVisualProgressToNextLevel),
            passiveIncomeAmount: treePassiveIncomeAmount,
            memberCount: humans.count + pets.count,
            localization: l
        )
    }

    // MARK: - Inject Energy Button

    private var injectEnergyButton: some View {
        let canInject = canInjectTreeEnergy
        return Button {
            injectTreeEnergy()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill") // a11y: allow decorative action icon paired with label
                    .accessibilityHidden(true)
                Text(l.tr(zh: "注入能量", en: "Inject energy", de: "Energie geben"))
                    .font(OhanaFont.headline(.black))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                Text("(-80🥥)")
                    .font(OhanaFont.subheadline(.bold))
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

    private var milestoneCard: some View {
        OasisMilestoneCard(treeLevel: treeVisualLevel, localization: l)
    }

    // MARK: - 模块六：打卡日历（完整月视图）

    @State private var calendarDisplayMonth: Date = Date()

    private var checkInCalendarCard: some View {
        OasisCheckInCalendarCard(
            displayMonth: $calendarDisplayMonth,
            checkedInDates: checkedInDates,
            makeupDates: makeupDates,
            makeupPackCount: makeupPackCount,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            monthCheckInRate: monthCheckInRate,
            lastClaimedMilestone: lastClaimedMilestone,
            localization: l,
            onRequestMakeup: { date in
                confirmationRoute = .makeup(date: date)
            },
            onOpenMakeupShop: {
                openSheet(.coconutShop(.boost))
            },
            onClaimMilestone: claimMilestone
        )
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
                openSheet(.coconutShop(.effect))
            },
            onOpenAchievements: {
                openSheet(.achievements)
            },
            onOpenCritters: {
                openSheet(.critterCodex)
            },
            onOpenGacha: {
                openSheet(.gacha)
            }
        )
    }

    // MARK: - Animations

    private func startAmbientMotionIfNeeded() {
        updateGlowMotion()
        startBreathing()
    }

    private func stopAmbientMotion() {
        glowBreathing = false
        treeScale = 1.0
        treeGlow = 0.4
    }

    private func updateGlowMotion() {
        glowBreathing = shouldRunAmbientMotion
    }

    private func startBreathing() {
        guard shouldRunAmbientMotion else {
            treeScale = 1.0
            treeGlow = 0.4
            return
        }
        withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) { // ui-v4: allow AppWorkloadPolicy-gated Oasis ambient breathing; smoothness: allow visible-only ambient tree scale
            treeScale = 1.055
            treeGlow  = 0.7
        }
    }

    private func triggerLevelUpFeedback() {
        guard !levelUpPulse else { return }
        OhanaFeedback.success()
        spawnEnergyParticles(count: 22)
        withAnimation(GoMotion.rewardPop) {
            levelUpPulse = true
            levelUpBadgeVisible = true
        }
        levelUpFeedbackTask?.cancel()
        levelUpFeedbackTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 280) {
            withAnimation(GoMotion.stateChange) {
                levelUpPulse = false
            }
            levelUpFeedbackTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 920) {
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

#Preview {
    OasisRewardView()
        .modelContainer(SharedModelContainer.make())
}
