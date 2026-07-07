import Foundation

extension HygieneType {
    /// UserDefaults key for custom cycle
    nonisolated static func customCycleDaysKey(petId: UUID, type: HygieneType) -> String {
        PetHygieneCyclePreferenceStore.customCycleDaysKey(petId: petId, type: type)
    }

    /// 读取某只宠物某类型的自定义周期天数（nil 表示使用默认值）
    nonisolated static func customCycleDays(for type: HygieneType, petId: UUID) -> Int? {
        PetHygieneCyclePreferenceStore.customCycleDays(for: type, petId: petId)
    }

    /// 设定自定义周期天数（≤0 表示恢复默认）
    nonisolated static func setCustomCycleDays(_ days: Int, for type: HygieneType, petId: UUID) {
        PetHygieneCyclePreferenceStore.setCustomCycleDays(days, for: type, petId: petId)
    }

    /// 获取针对特定宠物的实际周期天数（自定义优先）
    nonisolated func effectiveCycleDays(for petId: UUID) -> Int {
        HygieneType.customCycleDays(for: self, petId: petId) ?? defaultCycleDays
    }

    nonisolated func cycleStatus(
        lastDate: Date?,
        petId: UUID,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> CareCycleStatus? {
        CareCycleStatus.make(
            lastDate: lastDate,
            intervalDays: effectiveCycleDays(for: petId),
            now: now,
            calendar: calendar
        )
    }
}

private enum PetHygieneCyclePreferenceStore {
    nonisolated static func customCycleDays(for type: HygieneType, petId: UUID) -> Int? {
        let value = UserDefaults.standard.integer(forKey: customCycleDaysKey(petId: petId, type: type))
        return value > 0 ? value : nil
    }

    nonisolated static func setCustomCycleDays(_ days: Int, for type: HygieneType, petId: UUID) {
        let key = customCycleDaysKey(petId: petId, type: type)
        if days > 0 {
            UserDefaults.standard.set(days, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    nonisolated static func customCycleDaysKey(petId: UUID, type: HygieneType) -> String {
        "hygiene_cycle_\(petId.uuidString)_\(type.rawValue)"
    }
}
