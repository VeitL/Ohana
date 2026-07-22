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
}

@MainActor
final class SystemSurfaceSnapshotCoordinator: SystemSurfaceSnapshotRefreshing {
    private let modelContainer: ModelContainer
    private let activeHumanSelection: ActiveHumanSelecting
    private let commerce: CommerceEntitlementService
    private let revisions: DomainRevisionPublishing
    private let store: SystemSurfaceSnapshotStore
    private let workloadPolicy: AppWorkloadPolicy
    private let reloadWidget: () -> Void
    private var subscriptions: Set<AnyCancellable> = []
    private var refreshTask: Task<Void, Never>?
    private var didStart = false

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
        self.modelContainer = modelContainer
        self.activeHumanSelection = activeHumanSelection
        self.commerce = commerce
        self.revisions = revisions
        self.store = store
        self.workloadPolicy = workloadPolicy ?? AppWorkloadPolicy.shared
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
        refreshTask?.cancel()
        let debounceMilliseconds = workloadPolicy.systemSurfaceSnapshotDebounceMilliseconds()
        refreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(debounceMilliseconds))
            guard let self, !Task.isCancelled else { return }
            await refresh(reason: reason)
        }
    }

    private func refresh(reason: String) async {
        let languageCode = AppLanguage.code
        if !commerce.allows(.systemWidgets) {
            write(
                TodayCareWidgetSnapshot.upgradeRequired(languageCode: languageCode),
                reason: reason
            )
            return
        }

        do {
            let actor = TaskCenterRouteDataActor(modelContainer: modelContainer)
            let reference = try await actor.load(
                loadPlants: AppFeatureRouteGuard.shouldLoadPlantData,
                activeHumanID: activeHumanSelection.currentHumanId
            )
            guard !Task.isCancelled else { return }
            let snapshot = TodayCareWidgetSnapshotBuilder.make(
                taskCenter: reference.snapshot,
                languageCode: languageCode
            )
            write(snapshot, reason: reason)
        } catch is CancellationError {
            return
        } catch {
            write(
                TodayCareWidgetSnapshot.unavailable(languageCode: languageCode),
                reason: "\(reason).safeFallback"
            )
            OhanaLog.warning(
                "Widget snapshot refresh failed (\(reason)): \(error.localizedDescription)",
                category: "SystemSurfaces"
            )
        }
    }

    private func write(_ snapshot: TodayCareWidgetSnapshot, reason: String) {
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
}

@MainActor
final class NoopSystemSurfaceSnapshotCoordinator: SystemSurfaceSnapshotRefreshing {
    func start() {}
    func scheduleRefresh(reason _: String) {}
}
