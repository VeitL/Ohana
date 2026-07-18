//
//  OasisHomeTabHost.swift
//  Ohana
//
//  Keeps the vertical home tab transition light by rendering a snapshot-only
//  Oasis shell. The full Oasis feature mounts from its own route, not Home.
//

import SwiftUI

enum OasisHomeTabContentPolicy {
    static func shouldRenderTreeContent(for lifecycle: VerticalSolidHomePageLifecycle) -> Bool {
        _ = lifecycle
        return false
    }

    static func shouldRenderFrozenTree(for lifecycle: VerticalSolidHomePageLifecycle) -> Bool {
        lifecycle.isPrepared || lifecycle.isPreparingForDisplay || lifecycle.isVisible
    }

    static func shouldRunActiveWork(for lifecycle: VerticalSolidHomePageLifecycle) -> Bool {
        _ = lifecycle
        return false
    }
}

struct OasisHomeTabHost: View {
    let lifecycle: VerticalSolidHomePageLifecycle
    let treeSnapshot: OasisTreeRenderSnapshot
    let injectEnergyTrigger: Int
    var onPresentCoconutLog: ((CoconutLogSubject?) -> Void)?
    var onInjectEnergy: () -> Void = {}
    var onOpenShop: (ShopItem.ShopCategory) -> Void = { _ in }
    var onOpenAchievements: () -> Void = {}
    var onOpenCritters: () -> Void = {}
    var onOpenGacha: () -> Void = {}

    @State private var showsTreeContent = false
    @State private var forwardedInjectEnergyTrigger = 0
    @State private var treeContentMountTask: Task<Void, Never>?
    @State private var injectHandoffTask: Task<Void, Never>?
    @State private var lifecycleHandoffTask: Task<Void, Never>?
    @State private var oasisFlowStartedAt: CFAbsoluteTime?
    @State private var didRecordShellReady = false
    @State private var didRecordFirstFrame = false
    @State private var didRecordContentMounted = false

    var body: some View {
        let rendersTreeContent = showsTreeContent && OasisHomeTabContentPolicy.shouldRenderTreeContent(for: lifecycle)
        let rendersFrozenTree = OasisHomeTabContentPolicy.shouldRenderFrozenTree(for: lifecycle)

        Group {
            if rendersTreeContent {
                OasisRewardView(
                    hideToolbar: true,
                    injectEnergyTrigger: forwardedInjectEnergyTrigger,
                    isEmbeddedPrepared: lifecycle.isPrepared,
                    isEmbeddedVisible: lifecycle.isVisible,
                    isEmbeddedActive: OasisHomeTabContentPolicy.shouldRunActiveWork(for: lifecycle),
                    onPresentCoconutLog: onPresentCoconutLog
                )
                .allowsHitTesting(OasisHomeTabContentPolicy.shouldRunActiveWork(for: lifecycle))
            } else if rendersFrozenTree {
                VerticalSolidHomeOasisFrozenTreeStage(
                    snapshot: treeSnapshot,
                    onInjectEnergy: onInjectEnergy,
                    onOpenShop: onOpenShop,
                    onOpenAchievements: onOpenAchievements,
                    onOpenCritters: onOpenCritters,
                    onOpenGacha: onOpenGacha
                )
            } else {
                Color.clear
                    .allowsHitTesting(false)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
        .padding(.horizontal, 10)
        .padding(.top, 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("oasis-screen")
        .onAppear {
            scheduleLifecycleHandoff()
        }
        .onDisappear {
            treeContentMountTask?.cancel()
            treeContentMountTask = nil
            unmountTreeContent()
            lifecycleHandoffTask?.cancel()
            lifecycleHandoffTask = nil
            injectHandoffTask?.cancel()
            injectHandoffTask = nil
            if let oasisFlowStartedAt {
                AppFlowPerformance.mark(
                    AppPerformanceFlows.oasisOpen,
                    AppPerformancePhases.routeDismiss,
                    startedAt: oasisFlowStartedAt
                )
            }
            oasisFlowStartedAt = nil
            didRecordShellReady = false
            didRecordFirstFrame = false
            didRecordContentMounted = false
        }
        .onChange(of: lifecycle) { _, _ in
            scheduleLifecycleHandoff()
        }
        .onChange(of: injectEnergyTrigger) { _, newValue in
            handleInjectEnergyTriggerChanged(newValue)
        }
    }

    private func updateTreeContentLifecycle() {
        guard lifecycle.isPrepared || lifecycle.isVisible || lifecycle.isLive else {
            treeContentMountTask?.cancel()
            treeContentMountTask = nil
            injectHandoffTask?.cancel()
            injectHandoffTask = nil
            unmountTreeContent()
            return
        }

        var startedAtForVisibleShell: CFAbsoluteTime?
        if OasisHomeTabContentPolicy.shouldRenderFrozenTree(for: lifecycle) {
            let startedAt = ensureFlowStarted()
            startedAtForVisibleShell = startedAt
            recordShellReadyIfNeeded(
                startedAt: startedAt,
                source: OasisHomeTabContentPolicy.shouldRenderTreeContent(for: lifecycle) ? "live_tree" : "frozen_tree"
            )
            if !didRecordFirstFrame {
                AppFlowPerformance.mark(
                    AppPerformanceFlows.oasisOpen,
                    AppPerformancePhases.firstFrame,
                    startedAt: startedAt,
                    note: [
                        "source": OasisHomeTabContentPolicy.shouldRenderTreeContent(for: lifecycle)
                            ? "live_tree"
                            : "frozen_tree"
                    ]
                )
                didRecordFirstFrame = true
            }
        }

        if OasisHomeTabContentPolicy.shouldRenderTreeContent(for: lifecycle) {
            let startedAt = startedAtForVisibleShell ?? ensureFlowStarted()
            scheduleTreeContentMount(startedAt: startedAt)
        } else {
            treeContentMountTask?.cancel()
            treeContentMountTask = nil
            unmountTreeContent()
        }

        if OasisHomeTabContentPolicy.shouldRunActiveWork(for: lifecycle) {
            schedulePendingInjectHandoff()
        } else {
            injectHandoffTask?.cancel()
            injectHandoffTask = nil
        }
    }

    private func scheduleLifecycleHandoff() {
        lifecycleHandoffTask?.cancel()
        lifecycleHandoffTask = OhanaFrameScheduler.runAfterNextFrame {
            resetFlowIfNeeded()
            updateTreeContentLifecycle()
            lifecycleHandoffTask = nil
        }
    }

    private func resetFlowIfNeeded() {
        guard lifecycle.isPrepared || lifecycle.isVisible || lifecycle.isLive else {
            oasisFlowStartedAt = nil
            didRecordShellReady = false
            didRecordFirstFrame = false
            didRecordContentMounted = false
            return
        }
    }

    private func ensureFlowStarted() -> CFAbsoluteTime {
        if let oasisFlowStartedAt {
            return oasisFlowStartedAt
        }
        let startedAt = AppFlowPerformance.start(
            AppPerformanceFlows.oasisOpen,
            note: ["source": "home_tab"]
        )
        oasisFlowStartedAt = startedAt
        return startedAt
    }

    private func recordShellReadyIfNeeded(startedAt: CFAbsoluteTime, source: String) {
        guard !didRecordShellReady else { return }
        AppFlowPerformance.mark(
            AppPerformanceFlows.oasisOpen,
            AppPerformancePhases.shellReady,
            startedAt: startedAt,
            note: [
                "prepared": lifecycle.isPrepared ? "true" : "false",
                "source": source
            ]
        )
        didRecordShellReady = true
    }

    private func scheduleTreeContentMount(startedAt: CFAbsoluteTime) {
        guard OasisHomeTabContentPolicy.shouldRenderTreeContent(for: lifecycle) else { return }
        guard !showsTreeContent else {
            recordContentMountedIfNeeded(startedAt: startedAt)
            return
        }
        treeContentMountTask?.cancel()
        treeContentMountTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 24) {
            guard OasisHomeTabContentPolicy.shouldRenderTreeContent(for: lifecycle) else {
                treeContentMountTask = nil
                return
            }
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                showsTreeContent = true
            }
            recordContentMountedIfNeeded(startedAt: startedAt)
            treeContentMountTask = nil
            schedulePendingInjectHandoff()
        }
    }

    private func recordContentMountedIfNeeded(startedAt: CFAbsoluteTime) {
        guard !didRecordContentMounted else { return }
        AppFlowPerformance.mark(
            AppPerformanceFlows.oasisOpen,
            AppPerformancePhases.contentMounted,
            startedAt: startedAt,
            note: ["source": "home_tab_tree"]
        )
        didRecordContentMounted = true
    }

    private func unmountTreeContent() {
        guard showsTreeContent else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            showsTreeContent = false
        }
        didRecordContentMounted = false
    }

    private func handleInjectEnergyTriggerChanged(_ newValue: Int) {
        guard forwardedInjectEnergyTrigger != newValue else { return }
        if showsTreeContent && OasisHomeTabContentPolicy.shouldRunActiveWork(for: lifecycle) {
            schedulePendingInjectHandoff(delayMilliseconds: 0)
        }
    }

    private func schedulePendingInjectHandoff(delayMilliseconds: UInt64 = 24) {
        guard OasisHomeTabContentPolicy.shouldRunActiveWork(for: lifecycle),
              showsTreeContent,
              forwardedInjectEnergyTrigger != injectEnergyTrigger else { return }
        injectHandoffTask?.cancel()
        injectHandoffTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: delayMilliseconds) {
            guard showsTreeContent,
                  OasisHomeTabContentPolicy.shouldRunActiveWork(for: lifecycle) else {
                injectHandoffTask = nil
                return
            }
            forwardedInjectEnergyTrigger = injectEnergyTrigger
            injectHandoffTask = nil
        }
    }
}
