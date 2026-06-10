//
//  OasisCritterViews+Runtime.swift
//  Ohana
//

import SwiftUI
import SwiftData
import UIKit

extension OasisCritterCodexView {
    var ownedCount: Int {
        electronicPets.filter { !$0.isArchived }.count
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
                fragments: fragments
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

    func scheduleCritterCommand(milliseconds: UInt64 = 60, _ operation: @escaping @MainActor () -> Void) {
        let taskId = UUID()
        critterCommandTasks[taskId] = OhanaFrameScheduler.runAfterNextFrame(milliseconds: milliseconds) {
            operation()
            critterCommandTasks[taskId] = nil
        }
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
        let fragmentCount = fragments.first(where: { $0.catalogId == entry.id })?.amount ?? 0
        let cost = OasisCritterPresentationRules.awakeningCost(for: entry.rarity)
        if fragmentCount > 0 {
            return "\(fragmentCount)/\(cost.fragments)◇"
        }
        return "Lv.\(entry.sourceLevel)"
    }
}
