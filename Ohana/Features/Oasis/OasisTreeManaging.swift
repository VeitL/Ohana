import Foundation
import SwiftData

@MainActor
protocol OasisTreeManaging {
    var treeLevel: TreeLevel { get }
    var progressToNextLevel: Double { get }
    var injectedEnergy: Int { get }
    var totalEnergy: Int { get }
    var nextLevelThreshold: Int { get }
    var passiveIncomeAmount: Int { get }
    var canHarvestToday: Bool { get }

    func treeLevel(forTotalEnergy totalEnergy: Int) -> TreeLevel
    func progressToNextLevel(forTotalEnergy totalEnergy: Int) -> Double
    func nextLevelThreshold(forTotalEnergy totalEnergy: Int) -> Int
    func canUseInjectionPackage(cost: Int, date: Date) -> Bool
    func applyPurchasedEnergyBoost(cost: Int, modelContext: ModelContext) -> Bool
    func refreshPreviewEnergy(modelContext: ModelContext, pets: [Pet], humans: [Human], plants: [Plant])
    func refreshEnergy(modelContext: ModelContext, pets: [Pet], humans: [Human], plants: [Plant])
    @discardableResult
    func refreshLedgerEnergy(modelContext: ModelContext) -> TreeLevel
    func dailyTreeCoconutSnapshot(maxCoconutCount: Int, date: Date) -> OasisDailyTreeCoconutSnapshot
    func markDailyTreeCoconutHarvested(_ index: Int, maxCoconutCount: Int, date: Date) -> OasisDailyTreeCoconutSnapshot
    func markDailyPassiveIncomeHarvested(date: Date)
    func injectEnergy(cost: Int, modelContext: ModelContext) -> Bool
}

extension OasisTreeManaging {
    func canUseInjectionPackage(cost: Int) -> Bool {
        canUseInjectionPackage(cost: cost, date: Date())
    }

    func dailyTreeCoconutSnapshot(maxCoconutCount: Int) -> OasisDailyTreeCoconutSnapshot {
        dailyTreeCoconutSnapshot(maxCoconutCount: maxCoconutCount, date: Date())
    }

    func markDailyTreeCoconutHarvested(
        _ index: Int,
        maxCoconutCount: Int
    ) -> OasisDailyTreeCoconutSnapshot {
        markDailyTreeCoconutHarvested(index, maxCoconutCount: maxCoconutCount, date: Date())
    }
}

@MainActor
final class SharedOasisTreeManager: OasisTreeManaging {
    private let manager: OasisTreeManager

    init() {
        manager = OasisTreeManagerRegistry.current
    }

    init(manager: OasisTreeManager) {
        self.manager = manager
    }

    var treeLevel: TreeLevel {
        manager.treeLevel
    }

    var progressToNextLevel: Double {
        manager.progressToNextLevel
    }

    var totalEnergy: Int {
        manager.totalEnergy
    }

    var nextLevelThreshold: Int {
        manager.nextLevelThreshold
    }

    var passiveIncomeAmount: Int {
        manager.passiveIncomeAmount
    }

    var canHarvestToday: Bool {
        manager.canHarvestToday
    }

    var injectedEnergy: Int {
        manager.injectedEnergy
    }

    func treeLevel(forTotalEnergy totalEnergy: Int) -> TreeLevel {
        OasisTreeManager.treeLevel(forTotalEnergy: totalEnergy)
    }

    func progressToNextLevel(forTotalEnergy totalEnergy: Int) -> Double {
        OasisTreeManager.progressToNextLevel(forTotalEnergy: totalEnergy)
    }

    func nextLevelThreshold(forTotalEnergy totalEnergy: Int) -> Int {
        OasisTreeManager.nextLevelThreshold(forTotalEnergy: totalEnergy)
    }

    func canUseInjectionPackage(cost: Int, date: Date = Date()) -> Bool {
        manager.canUseInjectionPackage(cost: cost, date: date)
    }

    func applyPurchasedEnergyBoost(cost: Int, modelContext: ModelContext) -> Bool {
        manager.applyPurchasedEnergyBoost(cost: cost, modelContext: modelContext)
    }

    func refreshPreviewEnergy(modelContext: ModelContext, pets: [Pet], humans: [Human], plants: [Plant]) {
        manager.refreshPreviewEnergy(modelContext: modelContext, pets: pets, humans: humans, plants: plants)
    }

    func refreshEnergy(modelContext: ModelContext, pets: [Pet], humans: [Human], plants: [Plant]) {
        manager.refreshEnergy(modelContext: modelContext, pets: pets, humans: humans, plants: plants)
    }

    @discardableResult
    func refreshLedgerEnergy(modelContext: ModelContext) -> TreeLevel {
        manager.refreshLedgerEnergy(modelContext: modelContext)
    }

    func dailyTreeCoconutSnapshot(maxCoconutCount: Int, date: Date = Date()) -> OasisDailyTreeCoconutSnapshot {
        manager.dailyTreeCoconutSnapshot(maxCoconutCount: maxCoconutCount, date: date)
    }

    func markDailyTreeCoconutHarvested(
        _ index: Int,
        maxCoconutCount: Int,
        date: Date = Date()
    ) -> OasisDailyTreeCoconutSnapshot {
        manager.markDailyTreeCoconutHarvested(index, maxCoconutCount: maxCoconutCount, date: date)
    }

    func markDailyPassiveIncomeHarvested(date: Date = Date()) {
        manager.markDailyPassiveIncomeHarvested(date: date)
    }

    func injectEnergy(cost: Int, modelContext: ModelContext) -> Bool {
        manager.injectEnergy(cost: cost, modelContext: modelContext)
    }
}
