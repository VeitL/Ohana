//
//  StreakManager.swift
//  Ohana
//
//  羁绊值管理器：根据每日打卡（遛狗/喂食/便便）更新 currentStreak

import SwiftData
import Foundation

struct StreakManager {
    /// 检查并更新 pet 的 streak。
    /// 规则：今日有任意一条 pottyLog / walkLog / foodRecord 即视为打卡。
    /// 调用时机：App foreground / 任意记录写入后。
    @MainActor
    static func refreshStreak(for pet: Pet, context: ModelContext) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!

        let checkedInToday = hasCheckIn(pet: pet, on: today)

        if let lastDate = pet.lastCheckInDate {
            let lastDay = cal.startOfDay(for: lastDate)

            if cal.isDate(lastDay, inSameDayAs: today) {
                // 今天已经记录过，streak 不变
                return
            } else if cal.isDate(lastDay, inSameDayAs: yesterday) {
                // 昨天有记录，今天也有 → streak +1
                if checkedInToday {
                    pet.currentStreak += 1
                    pet.lastCheckInDate = Date()
                }
                // 昨天有记录，今天还没有 → 暂不处理，等今天打卡
            } else {
                // 超过1天没打卡 → 检查 Streak 保护盾
                let shieldKey = "shop_streakShieldExpiry"
                let shieldExpiry = UserDefaults.standard.object(forKey: shieldKey) as? Date
                let shieldActive = shieldExpiry.map { Date() < $0 } ?? false

                if checkedInToday {
                    if shieldActive {
                        // 保护盾消耗：streak 继续（+1），不重置
                        pet.currentStreak += 1
                        pet.lastCheckInDate = Date()
                        UserDefaults.standard.removeObject(forKey: shieldKey)
                    } else {
                        pet.currentStreak = 1
                        pet.lastCheckInDate = Date()
                    }
                } else if !shieldActive {
                    pet.currentStreak = 0
                }
            }
        } else {
            // 首次打卡
            if checkedInToday {
                pet.currentStreak = 1
                pet.lastCheckInDate = Date()
            }
        }

        context.safeSave()
    }

    private static func hasCheckIn(pet: Pet, on day: Date) -> Bool {
        let cal = Calendar.current
        let hasPotty  = pet.pottyLogs.contains  { cal.isDate($0.date, inSameDayAs: day) }
        let hasWalk   = pet.walkLogs.contains   { cal.isDate($0.startDate, inSameDayAs: day) }
        let hasFood   = pet.foodRecords.contains { cal.isDate($0.startDate, inSameDayAs: day) }
        return hasPotty || hasWalk || hasFood
    }

    /// 最高 streak 的宠物
    static func topStreakPet(pets: [Pet]) -> Pet? {
        pets.max(by: { $0.currentStreak < $1.currentStreak })
    }
}
