//
//  HomeV2Controller.swift
//  Ohana
//
//  Local visual state and cancellable background handoffs for Home V2.
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class HomeV2Controller: ObservableObject {
    @Published private(set) var selectedTab: HomeV2Tab = .home
    @Published private(set) var preparedTabs: Set<HomeV2Tab> = [.home]
    @Published private(set) var snapshot: HomeV2Snapshot

    private var snapshotSignature: String
    private var snapshotTask: Task<Void, Never>?
    private var warmupTask: Task<Void, Never>?
    private var deferredPrepareTask: Task<Void, Never>?

    init(initialSnapshot: HomeV2Snapshot, initialSignature: String) {
        snapshot = initialSnapshot
        snapshotSignature = initialSignature
    }

    var isCurrentTabPrepared: Bool {
        preparedTabs.contains(selectedTab)
    }

    func select(_ tab: HomeV2Tab) {
        guard selectedTab != tab else {
            deferredPrepareTask?.cancel()
            deferredPrepareTask = nil
            return
        }

        deferredPrepareTask?.cancel()
        guard !preparedTabs.contains(tab) else {
            selectedTab = tab
            return
        }

        deferredPrepareTask = Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: 32)
            guard !Task.isCancelled else { return }
            prepare(tab)
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: 16)
            guard !Task.isCancelled else { return }
            selectedTab = tab
            deferredPrepareTask = nil
        }
    }

    func startWarmup() {
        guard preparedTabs.count < HomeV2Tab.allCases.count else { return }
        warmupTask?.cancel()
        warmupTask = Task { @MainActor in
            for tab in [HomeV2Tab.calendar, .oasis, .plants] {
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
        build: @escaping @MainActor () -> HomeV2Snapshot
    ) {
        guard signature != snapshotSignature else { return }
        snapshotTask?.cancel()
        snapshotTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: delayMilliseconds) { [weak self] in
            guard let self else { return }
            applySnapshot(build(), signature: signature)
            snapshotTask = nil
        }
    }

    func applySnapshot(_ next: HomeV2Snapshot, signature: String, force: Bool = false) {
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
        snapshotTask = nil
        warmupTask = nil
        deferredPrepareTask = nil
    }

    private func prepare(_ tab: HomeV2Tab) {
        guard !preparedTabs.contains(tab) else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            _ = preparedTabs.insert(tab)
        }
    }

    private func warmupDelay(for tab: HomeV2Tab) -> UInt64 {
        switch tab {
        case .home: return 0
        case .calendar: return 80
        case .oasis: return 220
        case .plants: return 360
        }
    }
}
