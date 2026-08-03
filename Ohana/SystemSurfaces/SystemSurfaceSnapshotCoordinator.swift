//
//  SystemSurfaceSnapshotCoordinator.swift
//  Ohana
//
//  Keeps the WidgetKit projection synchronized after committed domain changes.
//

import Combine
import Foundation
import SwiftData
import WidgetKit

@MainActor
protocol SystemSurfaceSnapshotRefreshing: AnyObject {
    func start()
    func scheduleRefresh(reason: String)
    func prepareForAppReset()
    func finishAppReset()
}

@MainActor
final class SystemSurfaceSnapshotCoordinator: SystemSurfaceSnapshotRefreshing {
    private let revisions: DomainRevisionPublishing
    private let store: SystemSurfaceSnapshotStore
    private let reloadWidget: () -> Void
    private let debounceMilliseconds: () -> Int64
    private let allowsSystemWidgets: () -> Bool
    private let loadSnapshot: () async throws -> TaskCenterSnapshot
    private var subscriptions: Set<AnyCancellable> = []
    private var refreshTask: Task<Void, Never>?
    private var didStart = false
    private var refreshGeneration: UInt64 = 0
    private var isResetInProgress = false

    init(
        modelContainer: ModelContainer,
        activeHumanSelection: ActiveHumanSelecting,
        commerce: CommerceEntitlementService,
        revisions: DomainRevisionPublishing,
        store: SystemSurfaceSnapshotStore = .live,
        workloadPolicy: AppWorkloadPolicy? = nil,
        reloadWidget: @escaping () -> Void = {
            WidgetCenter.shared.reloadTimelines(ofKind: OhanaSystemSurfaceConstants.todayCareWidgetKind)
        }
    ) {
        self.revisions = revisions
        self.store = store
        self.reloadWidget = reloadWidget
        let workloadPolicy = workloadPolicy ?? AppWorkloadPolicy.shared
        debounceMilliseconds = {
            workloadPolicy.systemSurfaceSnapshotDebounceMilliseconds()
        }
        allowsSystemWidgets = {
            commerce.allows(.systemWidgets)
        }
        loadSnapshot = {
            let actor = TaskCenterRouteDataActor(modelContainer: modelContainer)
            let reference = try await actor.load(
                loadPlants: AppFeatureRouteGuard.shouldLoadPlantData,
                activeHumanID: activeHumanSelection.currentHumanId
            )
            return reference.snapshot
        }
    }

    init(
        revisions: DomainRevisionPublishing,
        store: SystemSurfaceSnapshotStore,
        debounceMilliseconds: @escaping () -> Int64,
        allowsSystemWidgets: @escaping () -> Bool,
        loadSnapshot: @escaping () async throws -> TaskCenterSnapshot,
        reloadWidget: @escaping () -> Void = {}
    ) {
        self.revisions = revisions
        self.store = store
        self.debounceMilliseconds = debounceMilliseconds
        self.allowsSystemWidgets = allowsSystemWidgets
        self.loadSnapshot = loadSnapshot
        self.reloadWidget = reloadWidget
    }

    deinit {
        refreshTask?.cancel()
    }

    func start() {
        guard !didStart else { return }
        didStart = true
        revisions.homeRevisionUpdates
            .sink { [weak self] _ in
                self?.scheduleRefresh(reason: "domainRevision")
            }
            .store(in: &subscriptions)
        scheduleRefresh(reason: "startup")
    }

    func scheduleRefresh(reason: String) {
        guard !isResetInProgress else { return }
        refreshTask?.cancel()
        refreshGeneration &+= 1
        let generation = refreshGeneration
        let debounceMilliseconds = debounceMilliseconds()
        refreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(debounceMilliseconds))
            guard let self,
                  !Task.isCancelled,
                  isCurrent(generation: generation) else { return }
            await refresh(reason: reason, generation: generation)
        }
    }

    func prepareForAppReset() {
        isResetInProgress = true
        refreshGeneration &+= 1
        refreshTask?.cancel()
    }

    func finishAppReset() {
        refreshGeneration &+= 1
        isResetInProgress = false
    }

    func waitForRefreshQuiescenceForTesting() async {
        await refreshTask?.value
    }

    private func refresh(reason: String, generation: UInt64) async {
        guard isCurrent(generation: generation) else { return }
        let languageCode = AppLanguage.code
        if !allowsSystemWidgets() {
            write(
                TodayCareWidgetSnapshot.upgradeRequired(languageCode: languageCode),
                reason: reason,
                generation: generation
            )
            return
        }

        do {
            let taskCenterSnapshot = try await loadSnapshot()
            guard !Task.isCancelled,
                  isCurrent(generation: generation) else { return }
            let snapshot = TodayCareWidgetSnapshotBuilder.make(
                taskCenter: taskCenterSnapshot,
                languageCode: languageCode
            )
            write(snapshot, reason: reason, generation: generation)
        } catch is CancellationError {
            return
        } catch {
            guard isCurrent(generation: generation) else { return }
            write(
                TodayCareWidgetSnapshot.unavailable(languageCode: languageCode),
                reason: "\(reason).safeFallback",
                generation: generation
            )
            OhanaLog.warning(
                "Widget snapshot refresh failed (\(reason)): \(error.localizedDescription)",
                category: "SystemSurfaces"
            )
        }
    }

    private func write(
        _ snapshot: TodayCareWidgetSnapshot,
        reason: String,
        generation: UInt64
    ) {
        guard isCurrent(generation: generation) else { return }
        do {
            try store.write(snapshot)
            reloadWidget()
        } catch SystemSurfaceSnapshotStore.StoreError.containerUnavailable {
            // A simulator, test host, or unsigned build can legitimately lack the
            // provisioned App Group. The app remains fully functional without it.
        } catch {
            OhanaLog.warning(
                "Widget snapshot write failed (\(reason)): \(error.localizedDescription)",
                category: "SystemSurfaces"
            )
        }
    }

    private func isCurrent(generation: UInt64) -> Bool {
        !isResetInProgress && generation == refreshGeneration
    }
}

@MainActor
final class NoopSystemSurfaceSnapshotCoordinator: SystemSurfaceSnapshotRefreshing {
    func start() {}
    func scheduleRefresh(reason _: String) {}
    func prepareForAppReset() {}
    func finishAppReset() {}
}
