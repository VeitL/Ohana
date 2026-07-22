import Foundation

nonisolated struct ShopConsumableInventorySnapshot: Equatable, Sendable {
    let backdatePassCount: Int
    let avatar2DExtraPassCount: Int
    let isDoubleRewardBoostActive: Bool
    let streakShieldExpiry: Date?
}

nonisolated protocol ShopInventoryManaging {
    func activateDoubleRewardBoost()
    func isDoubleRewardBoostActive() -> Bool
    func clearDoubleRewardBoost()
    func activateStreakShield(until expiry: Date)
    func clearStreakShield()
    func addBackdatePasses(_ count: Int)
    func consumeBackdatePass() -> Int?
    func addAvatar2DPasses(_ count: Int)
    func consumeAvatar2DPass() -> Bool
    func fulfillPurchase(itemID: String, attemptID: UUID, purchasedAt: Date) -> Bool
    func hasAppliedPurchase(attemptID: UUID) -> Bool
    func consumableSnapshot() -> ShopConsumableInventorySnapshot
}

nonisolated enum ShopInventoryDefaultsKeys {
    static let avatar2DExtraPassInventory = "inventory_avatar2d_extra_count"
    static let doubleRewardBoost = "shop_boostDoubleActive"
    static let streakShieldExpiry = "shop_streakShieldExpiry"
    static let durableStateV2 = "shop_inventory_durable_state_v2"
}

private nonisolated struct ShopInventoryDurableState: Codable, Sendable {
    var version = 2
    var backdatePassCount = 0
    var avatar2DExtraPassCount = 0
    var doubleRewardBoostActive = false
    var streakShieldExpiry: Date?
    var appliedPurchaseIDs: Set<String> = []
}

/// Keeps the inventory value and its idempotency markers in one encoded value.
/// Legacy scalar keys remain projections for existing `@AppStorage` readers and
/// older backups. Once the encoded value exists it is authoritative; restore
/// must explicitly replace it through `replaceFromBackup` so a stale scalar can
/// never roll durable inventory or an idempotency marker backward.
nonisolated enum ShopInventoryStateStore {
    private static let lock = NSLock()

    static func snapshot(defaults: UserDefaults = .standard) -> ShopConsumableInventorySnapshot {
        withState(defaults: defaults) { state in
            ShopConsumableInventorySnapshot(
                backdatePassCount: state.backdatePassCount,
                avatar2DExtraPassCount: state.avatar2DExtraPassCount,
                isDoubleRewardBoostActive: state.doubleRewardBoostActive,
                streakShieldExpiry: state.streakShieldExpiry
            )
        }
    }

    static func activateDoubleRewardBoost(defaults: UserDefaults = .standard) {
        mutate(defaults: defaults) { $0.doubleRewardBoostActive = true }
    }

    static func clearDoubleRewardBoost(defaults: UserDefaults = .standard) {
        mutate(defaults: defaults) { $0.doubleRewardBoostActive = false }
    }

    static func activateStreakShield(until expiry: Date, defaults: UserDefaults = .standard) {
        mutate(defaults: defaults) { state in
            state.streakShieldExpiry = max(state.streakShieldExpiry ?? .distantPast, expiry)
        }
    }

    static func clearStreakShield(defaults: UserDefaults = .standard) {
        mutate(defaults: defaults) { $0.streakShieldExpiry = nil }
    }

    static func addBackdatePasses(_ count: Int, defaults: UserDefaults = .standard) {
        guard count > 0 else { return }
        mutate(defaults: defaults) { $0.backdatePassCount += count }
    }

    static func consumeBackdatePass(defaults: UserDefaults = .standard) -> Int? {
        mutate(defaults: defaults) { state in
            guard state.backdatePassCount > 0 else { return nil }
            state.backdatePassCount -= 1
            return state.backdatePassCount
        }
    }

    static func addAvatar2DPasses(_ count: Int, defaults: UserDefaults = .standard) {
        guard count > 0 else { return }
        mutate(defaults: defaults) { $0.avatar2DExtraPassCount += count }
    }

    static func consumeAvatar2DPass(defaults: UserDefaults = .standard) -> Bool {
        mutate(defaults: defaults) { state in
            guard state.avatar2DExtraPassCount > 0 else { return false }
            state.avatar2DExtraPassCount -= 1
            return true
        }
    }

    static func fulfillPurchase(
        itemID: String,
        attemptID: UUID,
        purchasedAt: Date,
        now: Date = Date(),
        defaults: UserDefaults = .standard
    ) -> Bool {
        mutate(defaults: defaults) { state in
            let key = attemptID.uuidString
            guard !state.appliedPurchaseIDs.contains(key) else { return true }
            switch itemID {
            case "boost_double":
                state.doubleRewardBoostActive = true
            case "boost_streak":
                let target = purchasedAt.addingTimeInterval(172_800)
                guard target > now else { return false }
                state.streakShieldExpiry = max(state.streakShieldExpiry ?? .distantPast, target)
            case "boost_backdate_single":
                state.backdatePassCount += 1
            case "boost_backdate_pack":
                state.backdatePassCount += 3
            case Avatar2DAccess.shopItemId:
                state.avatar2DExtraPassCount += 1
            default:
                return false
            }
            state.appliedPurchaseIDs.insert(key)
            return true
        }
    }

    static func hasAppliedPurchase(attemptID: UUID, defaults: UserDefaults = .standard) -> Bool {
        withState(defaults: defaults) { $0.appliedPurchaseIDs.contains(attemptID.uuidString) }
    }

    static func replaceFromBackup(
        backdatePassCount: Int,
        avatar2DExtraPassCount: Int,
        doubleRewardBoostActive: Bool,
        streakShieldExpiry: Date?,
        defaults: UserDefaults
    ) {
        lock.lock()
        defer { lock.unlock() }
        persist(
            ShopInventoryDurableState(
                backdatePassCount: max(0, backdatePassCount),
                avatar2DExtraPassCount: max(0, avatar2DExtraPassCount),
                doubleRewardBoostActive: doubleRewardBoostActive,
                streakShieldExpiry: streakShieldExpiry,
                appliedPurchaseIDs: []
            ),
            defaults: defaults
        )
    }

    private static func withState<Value>(
        defaults: UserDefaults,
        _ body: (ShopInventoryDurableState) -> Value
    ) -> Value {
        lock.lock()
        defer { lock.unlock() }
        let state = load(defaults: defaults)
        repairLegacyProjections(state, defaults: defaults)
        return body(state)
    }

    private static func mutate<Value>(
        defaults: UserDefaults,
        _ body: (inout ShopInventoryDurableState) -> Value
    ) -> Value {
        lock.lock()
        defer { lock.unlock() }
        var state = load(defaults: defaults)
        let result = body(&state)
        persist(state, defaults: defaults)
        return result
    }

    private static func load(defaults: UserDefaults) -> ShopInventoryDurableState {
        guard let data = defaults.data(forKey: ShopInventoryDefaultsKeys.durableStateV2),
              let decoded = try? JSONDecoder().decode(ShopInventoryDurableState.self, from: data),
              decoded.version == 2 else {
            return ShopInventoryDurableState(
                backdatePassCount: max(0, defaults.integer(forKey: CheckInStreakStore.makeupPackKey)),
                avatar2DExtraPassCount: max(0, defaults.integer(forKey: ShopInventoryDefaultsKeys.avatar2DExtraPassInventory)),
                doubleRewardBoostActive: defaults.bool(forKey: ShopInventoryDefaultsKeys.doubleRewardBoost),
                streakShieldExpiry: defaults.object(forKey: ShopInventoryDefaultsKeys.streakShieldExpiry) as? Date
            )
        }
        return decoded
    }

    private static func persist(_ state: ShopInventoryDurableState, defaults: UserDefaults) {
        // Once present, this single encoded value is authoritative. It stores
        // both the inventory mutation and its purchase marker, so recovery
        // cannot observe one without the other.
        if let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: ShopInventoryDefaultsKeys.durableStateV2)
        }
        repairLegacyProjections(state, defaults: defaults)
    }

    private static func repairLegacyProjections(
        _ state: ShopInventoryDurableState,
        defaults: UserDefaults
    ) {
        let backdate = max(0, state.backdatePassCount)
        if defaults.integer(forKey: CheckInStreakStore.makeupPackKey) != backdate {
            defaults.set(backdate, forKey: CheckInStreakStore.makeupPackKey)
        }
        let avatar = max(0, state.avatar2DExtraPassCount)
        if defaults.integer(forKey: ShopInventoryDefaultsKeys.avatar2DExtraPassInventory) != avatar {
            defaults.set(avatar, forKey: ShopInventoryDefaultsKeys.avatar2DExtraPassInventory)
        }
        if defaults.bool(forKey: ShopInventoryDefaultsKeys.doubleRewardBoost) != state.doubleRewardBoostActive {
            defaults.set(state.doubleRewardBoostActive, forKey: ShopInventoryDefaultsKeys.doubleRewardBoost)
        }
        if let expiry = state.streakShieldExpiry {
            if defaults.object(forKey: ShopInventoryDefaultsKeys.streakShieldExpiry) as? Date != expiry {
                defaults.set(expiry, forKey: ShopInventoryDefaultsKeys.streakShieldExpiry)
            }
        } else if defaults.object(forKey: ShopInventoryDefaultsKeys.streakShieldExpiry) != nil {
            defaults.removeObject(forKey: ShopInventoryDefaultsKeys.streakShieldExpiry)
        }
    }
}

final nonisolated class UserDefaultsShopInventoryManager: ShopInventoryManaging {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func activateDoubleRewardBoost() {
        ShopInventoryStateStore.activateDoubleRewardBoost(defaults: defaults)
    }

    func isDoubleRewardBoostActive() -> Bool {
        ShopInventoryStateStore.snapshot(defaults: defaults).isDoubleRewardBoostActive
    }

    func clearDoubleRewardBoost() {
        ShopInventoryStateStore.clearDoubleRewardBoost(defaults: defaults)
    }

    func activateStreakShield(until expiry: Date) {
        ShopInventoryStateStore.activateStreakShield(until: expiry, defaults: defaults)
    }

    func clearStreakShield() {
        ShopInventoryStateStore.clearStreakShield(defaults: defaults)
    }

    func addBackdatePasses(_ count: Int) {
        ShopInventoryStateStore.addBackdatePasses(count, defaults: defaults)
    }

    func consumeBackdatePass() -> Int? {
        ShopInventoryStateStore.consumeBackdatePass(defaults: defaults)
    }

    func addAvatar2DPasses(_ count: Int) {
        ShopInventoryStateStore.addAvatar2DPasses(count, defaults: defaults)
    }

    func consumeAvatar2DPass() -> Bool {
        ShopInventoryStateStore.consumeAvatar2DPass(defaults: defaults)
    }

    func fulfillPurchase(itemID: String, attemptID: UUID, purchasedAt: Date) -> Bool {
        ShopInventoryStateStore.fulfillPurchase(
            itemID: itemID,
            attemptID: attemptID,
            purchasedAt: purchasedAt,
            defaults: defaults
        )
    }

    func hasAppliedPurchase(attemptID: UUID) -> Bool {
        ShopInventoryStateStore.hasAppliedPurchase(attemptID: attemptID, defaults: defaults)
    }

    func consumableSnapshot() -> ShopConsumableInventorySnapshot {
        ShopInventoryStateStore.snapshot(defaults: defaults)
    }
}
