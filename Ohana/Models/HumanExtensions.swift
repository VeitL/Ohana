//
//  HumanExtensions.swift
//  Ohana
//
//  模块3：Human 动态称号系统

import Foundation
import SwiftData

extension Human {

    // MARK: - 模块3：动态称号（计算属性）
    // 注意：SwiftData @Model 不支持需要跨模型 fetch 的计算属性，
    // 这里通过关联的 pets 数据计算（传入 allPets + allHumans）
    func dynamicBadges(allPets: [Pet], allHumans: [Human]) -> [HumanBadge] {
        var badges: [HumanBadge] = []
        let myId = id.uuidString
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()

        // 规则 A："💩 无情铲屎机"（过去 30 天 Litter 记录数 > 10）
        let allCareLogs: [PetCareLog] = allPets.flatMap { $0.careLogs }
        let recentLitter = allCareLogs.filter { log in
            log.executorId == myId && log.careType == .litter && log.date >= thirtyDaysAgo
        }
        if recentLitter.count > 10 {
            badges.append(HumanBadge(emoji: "💩", title: "无情铲屎机", color: "FFF44F"))
        }

        // 规则 B："💸 榜一大哥"（累计 Expense 金额全家最高）
        let allExpenseLogs: [PetExpenseLog] = allPets.flatMap { $0.expenseLogs }
        let myExpense = allExpenseLogs
            .filter { $0.executorId == myId }
            .reduce(0.0) { acc, log in acc + log.amount }
        let otherExpenses: [Double] = allHumans.filter { $0.id != id }.map { otherHuman in
            let oid = otherHuman.id.uuidString
            return allExpenseLogs.filter { $0.executorId == oid }.reduce(0.0) { acc, log in acc + log.amount }
        }
        let maxOtherExpense = otherExpenses.max() ?? 0
        if myExpense > 0 && myExpense >= maxOtherExpense {
            badges.append(HumanBadge(emoji: "💸", title: "榜一大哥", color: "C8FF00"))
        }

        // 规则 C："🥾 追风少年"（Walk 记录数 > 5）
        let allWalkLogs: [PetWalkLog] = allPets.flatMap { $0.walkLogs }
        let myWalks = allWalkLogs.filter { $0.executorId == myId }
        if myWalks.count > 5 {
            badges.append(HumanBadge(emoji: "🥾", title: "追风少年", color: "00D4AA"))
        }

        return badges
    }

    // 主题色（V15 起直接读 themeColorHex 字段）
    var themeColor: String { themeColorHex.isEmpty ? "4338FF" : themeColorHex }

    var avatarInitial: String { String(name.prefix(1)) }
}

// MARK: - HumanBadge 值类型
struct HumanBadge: Identifiable {
    let id = UUID()
    let emoji: String
    let title: String
    let color: String   // hex
}
