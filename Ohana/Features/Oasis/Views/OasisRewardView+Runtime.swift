//
//  OasisRewardView+Runtime.swift
//  Ohana
//

import SwiftUI

extension OasisRewardView {
    // MARK: - Star positions (deterministic)
    var starPositions: [(CGFloat, CGFloat)] {
        (0 ..< 8).map { i in
            let x = CGFloat((i * 53) % 320) - 160
            let y = CGFloat((i * 37) % 220) - 160
            return (x, y)
        }
    }



    @ViewBuilder
    var body: some View {
        if hideToolbar {
            oasisRuntimeContent
        } else {
            NavigationStack {
                oasisRuntimeContent
                    .navigationTitle(l.tr(zh: "绿洲", en: "Oasis", de: "Oase"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        OhanaModalToolbar(onClose: { dismiss() })
                        ToolbarItemGroup(placement: .primaryAction) {
                            Button { openSheet(.coconutRules) } label: {
                                Label(l.tr(zh: "椰子规则", en: "Coconut rules", de: "Kokosnuss-Regeln"), systemImage: "info.circle")
                            }
                            Button { openSheet(.inventory) } label: {
                                Label(l.tr(zh: "库存", en: "Inventory", de: "Inventar"), systemImage: "shippingbox.fill")
                            }
                        }
                    }
            }
        }
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
                        availableOasisCoconutBalance: availableOasisCoconutBalance,
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
                        humans: humans,
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
        }
        .sheet(isPresented: $showCritterNest) {
            OasisCritterCodexRouteContainer(
                mode: .nest,
                onClose: { showCritterNest = false },
                onPresentCoconutLog: onPresentCoconutLog ?? { _ in }
            )
            .presentationDetents([.medium, .large])
        }
        .alert(
            activeBentoFeatureInfo?.feature.title(l) ?? "",
            isPresented: Binding(
                get: { activeBentoFeatureInfo != nil },
                set: { if !$0 { activeBentoFeatureInfo = nil } }
            )
        ) {
            Button(l.tr(zh: "知道了", en: "Got it", de: "Verstanden"), role: .cancel) {
                activeBentoFeatureInfo = nil
            }
        } message: {
            if let info = activeBentoFeatureInfo {
                Text("\(info.statusText(l))\n\n\(info.feature.detail(l))")
            }
        }
    }

    @ViewBuilder
    var oasisBackgroundLayer: some View {
        if !hideToolbar {
            OhanaAppBackground()
                .ignoresSafeArea()
        }
    }

    var energyParticleLayer: some View {
        ForEach(energyParticles) { p in
            Image(systemName: "sparkles") // a11y: allow decorative energy particle
                .font(OhanaFont.brandTitle(.title3, weight: .bold))
                .foregroundStyle(Color.goPrimary)
                .offset(x: p.offsetX, y: p.offsetY)
                .opacity(p.opacity)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    var oasisScrollContent: some View {
        if hideToolbar {
            GeometryReader { proxy in
                let metrics = OasisEmbeddedLayoutPolicy.metrics(availableHeight: proxy.size.height)

                VStack(spacing: metrics.sectionSpacing) {
                    treeSceneCard(metrics: metrics)
                        .frame(height: metrics.treeCardHeight)

                    oasisBentoGrid
                        .frame(height: metrics.bentoGridHeight)
                }
                .padding(.horizontal, 16)
                .padding(.top, metrics.topPadding)
                .padding(.bottom, metrics.bottomPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        } else {
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

    func refreshLiveDataSnapshot(delayMilliseconds: UInt64 = 96, force: Bool = false) {
        liveDataStore.refresh(
            context: modelContext,
            delayMilliseconds: delayMilliseconds,
            force: force
        )
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
            refreshLiveDataSnapshot(delayMilliseconds: 0)
            commandExecutor.refreshPreviewEnergy(treeManager: treeMgr, pets: pets, humans: humans, plants: plants)
            lastLevel = treeMgr.treeLevel
            loadCheckInData()
            rebuildOasisRenderSnapshots(refreshLiveData: false)
            markVisibleStatePrepared()
            preparedWorkTask = nil
        }
    }

    func refreshVisibleState() {
        refreshLiveDataSnapshot(delayMilliseconds: 0)
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
            activeCoconutBalance: nextActionSnapshot.injectionCoconutBalance,
            careLedgerEvents: liveData.careLedgerEvents,
            petActivitySummaries: liveData.petActivitySummaries
        )
        critterRenderSnapshots = commandExecutor.makeCritterSnapshots(
            electronicPets: electronicPets,
            fragments: critterFragments,
            activeCoconutBalance: nextActionSnapshot.activeCoconutBalance
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
