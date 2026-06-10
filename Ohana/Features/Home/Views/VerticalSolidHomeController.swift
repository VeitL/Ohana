//
//  VerticalSolidHomeController.swift
//  Ohana
//
//  Local visual state and cancellable background handoffs for verticalSolid home.
//

import Combine
import Foundation
import SwiftUI

struct HomeSnapshotRefreshRequest: Equatable {
    let signature: String
    let delayMilliseconds: UInt64
}

struct HomeSnapshotRefreshGate: Equatable {
    static let normalDelayMilliseconds: UInt64 = 96
    static let postHeroDelayMilliseconds: UInt64 = 32

    private(set) var pendingSignature: String?

    mutating func dataDidChange(
        signature: String,
        isHeroAnimating: Bool
    ) -> HomeSnapshotRefreshRequest? {
        guard isHeroAnimating else {
            pendingSignature = nil
            return HomeSnapshotRefreshRequest(
                signature: signature,
                delayMilliseconds: Self.normalDelayMilliseconds
            )
        }

        pendingSignature = signature
        return nil
    }

    mutating func heroAnimationDidChange(isAnimating: Bool) -> HomeSnapshotRefreshRequest? {
        guard !isAnimating, let pendingSignature else { return nil }
        self.pendingSignature = nil
        return HomeSnapshotRefreshRequest(
            signature: pendingSignature,
            delayMilliseconds: Self.postHeroDelayMilliseconds
        )
    }

    mutating func cancel() {
        pendingSignature = nil
    }
}

@MainActor
final class VerticalSolidHomeController: ObservableObject {
    @Published private(set) var selectedTab: VerticalSolidHomeTab = .home
    @Published private(set) var outgoingTab: VerticalSolidHomeTab?
    @Published private(set) var preparingTab: VerticalSolidHomeTab?
    @Published private(set) var preparedTabs: Set<VerticalSolidHomeTab> = [.home]
    @Published private(set) var snapshot: VerticalSolidHomeSnapshot

    private var snapshotSignature: String
    private var snapshotTask: Task<Void, Never>?
    private var warmupTask: Task<Void, Never>?
    private var deferredPrepareTask: Task<Void, Never>?
    private var outgoingCleanupTask: Task<Void, Never>?

    init(initialSnapshot: VerticalSolidHomeSnapshot, initialSignature: String) {
        snapshot = initialSnapshot
        snapshotSignature = initialSignature
    }

    var isCurrentTabPrepared: Bool {
        preparedTabs.contains(selectedTab)
    }

    func select(_ tab: VerticalSolidHomeTab) {
        guard AppFeatureRouteGuard.allowsHomeTab(tab) else {
            AppFeatureRouteGuard.recordIntercept("homeTab:\(tab.rawValue)")
            return
        }
        guard selectedTab != tab else {
            deferredPrepareTask?.cancel()
            deferredPrepareTask = nil
            preparingTab = nil
            return
        }
        let startedAt = AppFlowPerformance.start(
            AppPerformanceFlows.homeTabSwitch,
            note: ["to": tab.rawValue]
        )

        deferredPrepareTask?.cancel()
        if preparedTabs.contains(tab) {
            preparingTab = nil
            commitTabSelection(tab, startedAt: startedAt)
            return
        }

        prepareForDisplay(tab)
        commitTabSelection(tab, startedAt: startedAt)
    }

    func startWarmup() {
        let visibleTabs = AppFeatureRouteGuard.visibleHomeTabs
        guard preparedTabs.count < visibleTabs.count else { return }
        warmupTask?.cancel()
        warmupTask = Task { @MainActor in
            for tab in visibleTabs where tab != .home {
                await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: warmupDelay(for: tab))
                guard !Task.isCancelled else { return }
                prepare(tab)
            }
            warmupTask = nil
        }
    }

    func scheduleSnapshotRefresh(
        signature: String,
        delayMilliseconds: UInt64 = 96,
        build: @escaping @MainActor () -> VerticalSolidHomeSnapshot
    ) {
        guard signature != snapshotSignature else { return }
        snapshotTask?.cancel()
        snapshotTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: delayMilliseconds) { [weak self] in
            guard let self else { return }
            applySnapshot(build(), signature: signature)
            snapshotTask = nil
        }
    }

    func applySnapshot(_ next: VerticalSolidHomeSnapshot, signature: String, force: Bool = false) {
        guard force || signature != snapshotSignature else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            snapshot = next
            snapshotSignature = signature
        }
    }

    func cancel() {
        snapshotTask?.cancel()
        warmupTask?.cancel()
        deferredPrepareTask?.cancel()
        outgoingCleanupTask?.cancel()
        snapshotTask = nil
        warmupTask = nil
        deferredPrepareTask = nil
        outgoingCleanupTask = nil
        outgoingTab = nil
        preparingTab = nil
    }

    private func commitTabSelection(_ tab: VerticalSolidHomeTab, startedAt: CFAbsoluteTime) {
        let previousTab = selectedTab
        outgoingCleanupTask?.cancel()
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            outgoingTab = previousTab
        }

        selectedTab = tab
        AppPerformanceMonitor.shared.record(
            "tab_switch_first_frame",
            startedAt: startedAt,
            note: String(describing: tab)
        )
        AppFlowPerformance.mark(
            AppPerformanceFlows.homeTabSwitch,
            AppPerformancePhases.firstFrame,
            startedAt: startedAt,
            note: ["from": previousTab.rawValue, "to": tab.rawValue]
        )

        outgoingCleanupTask = OhanaFrameScheduler.runAfterNextFrame(
            milliseconds: outgoingCleanupDelayMilliseconds
        ) { [weak self] in
            guard let self, self.outgoingTab == previousTab else { return }
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                self.outgoingTab = nil
            }
            AppFlowPerformance.mark(
                AppPerformanceFlows.homeTabSwitch,
                AppPerformancePhases.outgoingUnmounted,
                startedAt: startedAt,
                note: ["from": previousTab.rawValue, "to": tab.rawValue]
            )
            self.outgoingCleanupTask = nil
        }
    }

    private var outgoingCleanupDelayMilliseconds: UInt64 {
        VerticalHomeTabTransitionPolicy.outgoingCleanupDelayMilliseconds(
            for: AppWorkloadPolicy.shared.interactionMotionBudget(isVisible: true)
        )
    }

    private func prepare(_ tab: VerticalSolidHomeTab) {
        guard !preparedTabs.contains(tab) else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            _ = preparedTabs.insert(tab)
        }
    }

    private func prepareForDisplay(_ tab: VerticalSolidHomeTab) {
        preparingTab = tab
        deferredPrepareTask = Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: 24)
            guard !Task.isCancelled else { return }
            prepare(tab)
            guard !Task.isCancelled else { return }
            if preparingTab == tab {
                preparingTab = nil
            }
            deferredPrepareTask = nil
        }
    }

    private func warmupDelay(for tab: VerticalSolidHomeTab) -> UInt64 {
        switch tab {
        case .home: 0
        case .calendar: 80
        case .oasis: 220
        case .plants: 360
        }
    }
}
