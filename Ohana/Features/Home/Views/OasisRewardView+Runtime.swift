//
//  OasisRewardView+Runtime.swift
//  Ohana
//

import SwiftUI

extension OasisRewardView {
    // MARK: - Star positions (deterministic)
    var starPositions: [(CGFloat, CGFloat)] {
        (0 ..< 24).map { i in
            let x = CGFloat((i * 53) % 320) - 160
            let y = CGFloat((i * 37) % 220) - 160
            return (x, y)
        }
    }

    func oasisToolbarButton(systemName: String, action: @escaping () -> Void) -> some View {
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

    var oasisRuntimeContent: AnyView {
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

    var oasisPresentedContent: AnyView {
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

    var oasisRootContent: some View {
        ZStack {
            oasisBackgroundLayer

            energyParticleLayer
                .zIndex(99)

            oasisScrollContent

            oasisToolbarLayer

            critterNestLayer
        }
    }

    var oasisBackgroundLayer: some View {
        OhanaAppBackground()
            .ignoresSafeArea()
    }

    var energyParticleLayer: some View {
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

    var oasisScrollContent: some View {
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
    var oasisToolbarLayer: some View {
        if !hideToolbar {
            oasisFixedToolbar
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .zIndex(120)
        }
    }

    @ViewBuilder
    var critterNestLayer: some View {
        if showCritterNest || critterNestPopupProgress > 0.001 {
            critterNestPopupOverlay
                .zIndex(180)
        }
    }

    func handleOasisAppear() {
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

    func handleEmbeddedPreparedChanged(_ isPrepared: Bool) {
        if isPrepared {
            prepareVisibleShell()
        } else if !shouldTreatEmbeddedAsVisible {
            deactivateVisibleWork()
        }
    }

    func handleEmbeddedVisibleChanged(_ isVisible: Bool) {
        if isVisible {
            activateVisiblePresentation()
        } else if !isEmbeddedActive {
            deactivateVisiblePresentation()
        }
    }

    func handleEmbeddedActiveChanged(_ isActive: Bool) {
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

    func handleActiveHumanChanged() {
        guard isOasisPrepared else { return }
        scheduleOasisRenderSnapshotRefresh(milliseconds: 40)
        loadCheckInData()
        if isEmbeddedActive {
            scheduleTodayCheckIn()
        }
    }

    func handleAmbientMotionChanged(_ shouldAnimate: Bool) {
        if shouldAnimate {
            startAmbientMotionIfNeeded()
        } else {
            stopAmbientMotion()
        }
    }

    func activateVisibleWork() {
        prepareVisibleShell()
        activateVisiblePresentation()
        scheduleVisibleWork(delayMilliseconds: hideToolbar ? 120 : 60)
    }

    func activateVisiblePresentation() {
        prepareVisibleShell()
        isVisible = true
        startAmbientMotionIfNeeded()
    }

    func prepareVisibleShell() {
        guard isOasisPrepared else { return }
        isVisible = shouldTreatEmbeddedAsVisible
        lastLevel = treeMgr.treeLevel
        refreshTreeHarvestSnapshot()
        markVisibleStatePrepared()
        schedulePreparedVisualWork()
    }

    func deactivateVisiblePresentation() {
        isVisible = false
        stopAmbientMotion()
    }

    func deactivateVisibleWork() {
        isVisible = false
        isVisibleStatePrepared = false
        treeVisualEnergyOverride = nil
        coconutBalanceVisualOverride = nil
        isInjecting = false
        treeInjectionLocked = false
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
        treeStageAppearTask?.cancel()
        treeStageAppearTask = nil
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

    func refreshLiveDataSnapshot() {
        liveDataStore.refresh(context: modelContext)
    }

    func refreshOasisEnergyIfActive() {
        guard isEmbeddedActive, isVisibleStatePrepared else { return }
        scheduleVisibleWork(delayMilliseconds: 90)
        scheduleOasisRenderSnapshotRefresh(milliseconds: 120)
    }

    func refreshFeaturedCritterLifecycleIfActive() {
        guard isEmbeddedActive else { return }
        scheduleVisibleWork(delayMilliseconds: 120)
    }

    func injectTreeEnergyIfActive() {
        guard isEmbeddedActive else { return }
        injectTreeEnergy()
    }

    func scheduleVisibleWork(delayMilliseconds: UInt64? = nil) {
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

    func schedulePreparedVisualWork() {
        guard isOasisPrepared else { return }
        preparedWorkTask?.cancel()
        preparedWorkTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: preparedVisualWorkDelayMilliseconds) {
            guard isOasisPrepared else {
                preparedWorkTask = nil
                return
            }
            refreshLiveDataSnapshot()
            commandExecutor.refreshPreviewEnergy(treeManager: treeMgr, pets: pets, humans: humans, plants: plants)
            lastLevel = treeMgr.treeLevel
            loadCheckInData()
            rebuildOasisRenderSnapshots(refreshLiveData: false)
            markVisibleStatePrepared()
            preparedWorkTask = nil
        }
    }

    func refreshVisibleState() {
        refreshLiveDataSnapshot()
        commandExecutor.refreshEnergy(treeManager: treeMgr, pets: pets, humans: humans, plants: plants)
        commandExecutor.refreshFeaturedCritterLifecycle(electronicPets)
        lastLevel = treeMgr.treeLevel
        loadCheckInData()
        scheduleTodayCheckIn()
        rebuildOasisRenderSnapshots(refreshLiveData: false)
        markVisibleStatePrepared()
    }

    func markVisibleStatePrepared() {
        let wasPrepared = isVisibleStatePrepared
        isVisibleStatePrepared = true
        if wasPrepared {
            updateGlowMotion()
        } else {
            startAmbientMotionIfNeeded()
        }
    }

    func scheduleOasisRenderSnapshotRefresh(milliseconds: UInt64 = 80) {
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

    var preparedVisualWorkDelayMilliseconds: UInt64 {
        guard hideToolbar else { return 0 }
        return isEmbeddedActive ? 48 : 520
    }

    func rebuildOasisRenderSnapshots(refreshLiveData: Bool = true) {
        if refreshLiveData {
            refreshLiveDataSnapshot()
        }
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

    func refreshTreeHarvestSnapshot() {
        let capacity = BeautifulCoconutTree.coconutCapacity(for: treeVisualLevel.rawValue)
        let snapshot = treeMgr.dailyTreeCoconutSnapshot(maxCoconutCount: capacity)
        dailyTreeCoconutCount = snapshot.coconutCount
        harvestedCoconutIndices = snapshot.harvestedIndices.union(treeHarvestBuffer.pendingIndices)
        treePassiveIncomeAmount = snapshot.coconutCount
    }
}
