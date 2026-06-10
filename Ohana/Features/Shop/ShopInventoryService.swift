import Foundation

struct ShopConsumableInventorySnapshot: Equatable {
    let backdatePassCount: Int
    let isDoubleRewardBoostActive: Bool
    let streakShieldExpiry: Date?
}

nonisolated protocol ShopInventoryManaging {
    func activateDoubleRewardBoost()
    func isDoubleRewardBoostActive() -> Bool
    func clearDoubleRewardBoost()
    func activateStreakShield(until expiry: Date)
    func addBackdatePasses(_ count: Int)
    func consumeBackdatePass() -> Int?
    func consumableSnapshot() -> ShopConsumableInventorySnapshot
}

nonisolated enum ShopInventoryDefaultsKeys {
    static let avatar2DExtraPassInventory = "inventory_avatar2d_extra_count"
    static let doubleRewardBoost = "shop_boostDoubleActive"
    static let streakShieldExpiry = "shop_streakShieldExpiry"
}

final nonisolated class UserDefaultsShopInventoryManager: ShopInventoryManaging {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func activateDoubleRewardBoost() {
        defaults.set(true, forKey: ShopInventoryDefaultsKeys.doubleRewardBoost)
    }

    func isDoubleRewardBoostActive() -> Bool {
        defaults.bool(forKey: ShopInventoryDefaultsKeys.doubleRewardBoost)
    }

    func clearDoubleRewardBoost() {
        defaults.removeObject(forKey: ShopInventoryDefaultsKeys.doubleRewardBoost)
    }

    func activateStreakShield(until expiry: Date) {
        defaults.set(expiry, forKey: ShopInventoryDefaultsKeys.streakShieldExpiry)
    }

    func addBackdatePasses(_ count: Int) {
        guard count > 0 else { return }
        let current = defaults.integer(forKey: CheckInStreakStore.makeupPackKey)
        defaults.set(current + count, forKey: CheckInStreakStore.makeupPackKey)
    }

    func consumeBackdatePass() -> Int? {
        let current = defaults.integer(forKey: CheckInStreakStore.makeupPackKey)
        guard current > 0 else { return nil }
        let updated = current - 1
        defaults.set(updated, forKey: CheckInStreakStore.makeupPackKey)
        return updated
    }

    func consumableSnapshot() -> ShopConsumableInventorySnapshot {
        ShopConsumableInventorySnapshot(
            backdatePassCount: defaults.integer(forKey: CheckInStreakStore.makeupPackKey),
            isDoubleRewardBoostActive: defaults.bool(forKey: ShopInventoryDefaultsKeys.doubleRewardBoost),
            streakShieldExpiry: defaults.object(forKey: ShopInventoryDefaultsKeys.streakShieldExpiry) as? Date
        )
    }
}
