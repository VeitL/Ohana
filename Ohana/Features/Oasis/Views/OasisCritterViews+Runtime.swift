//
//  OasisCritterViews+Runtime.swift
//  Ohana
//

import SwiftData
import SwiftUI
import UIKit

extension OasisCritterCodexView {
    var ownedCount: Int {
        electronicPets.count(where: { !$0.isArchived })
    }

    func ownedCritter(_ catalogId: String) -> OasisElectronicPet? {
        electronicPets.first { $0.catalogId == catalogId && !$0.isArchived }
    }

    func renderSnapshot(for critter: OasisElectronicPet) -> OasisCritterRenderSnapshot {
        renderSnapshots[critter.id] ?? OasisCritterRenderSnapshot.lightweight(
            for: critter,
            rewards: appServices.oasisRewards
        )
    }

    func scheduleRenderSnapshotRefresh(milliseconds: UInt64 = 80) {
        renderSnapshotTask?.cancel()
        renderSnapshotTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: milliseconds) {
            renderSnapshots = commandExecutor.makeCritterSnapshots(
                electronicPets: electronicPets,
                fragments: fragments,
                activeCoconutBalance: currentCoconutBalance
            )
            renderSnapshotTask = nil
        }
    }

    func scheduleLifecycleRefresh(milliseconds: UInt64 = 120) {
        lifecycleRefreshTask?.cancel()
        lifecycleRefreshTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: milliseconds) {
            commandExecutor.refreshFeaturedCritterLifecycle(electronicPets)
            scheduleRenderSnapshotRefresh(milliseconds: 30)
            lifecycleRefreshTask = nil
        }
    }

    func scheduleCritterCommand(
        key: String,
        milliseconds: UInt64 = 60,
        _ operation: @escaping @MainActor () -> Void
    ) {
        guard critterCommandTasks[key] == nil else { return }
        critterCommandTasks[key] = OhanaFrameScheduler.runAfterNextFrame(milliseconds: milliseconds) {
            operation()
            critterCommandTasks[key] = nil
        }
    }

    func isGrowthCommandInFlight(catalogID: String) -> Bool {
        critterCommandTasks[catalogID] != nil
    }

    func cancelDeferredWork() {
        lifecycleRefreshTask?.cancel()
        renderSnapshotTask?.cancel()
        pulseCleanupTask?.cancel()
        rescueBusyCleanupTask?.cancel()
        outcomeCleanupTask?.cancel()
        critterCommandTasks.values.forEach { $0.cancel() }
        critterCommandTasks.removeAll()
    }

    func collectionStatus(for entry: OasisElectronicPetCatalogEntry, owned: Bool) -> String {
        if owned { return l.tr(zh: "已唤醒", en: "Awake", de: "Wach") }
        let availability = commandExecutor.awakenAvailability(catalogId: entry.id)
        let plan = availability.fundingPlan
        if availability.reason == .treeLevelLocked {
            return "Lv.\(entry.sourceLevel)"
        }
        if plan.requiredGrowthCurrency == 0 {
            return l.tr(zh: "免费唤醒", en: "Free awakening", de: "Kostenlos wecken")
        }
        return "\(plan.specificFragmentBalance)◇ + \(plan.stardustBalance)✦ / \(plan.requiredGrowthCurrency)"
    }
}
