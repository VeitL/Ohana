//
//  HomeBentoBoxes.swift
//  Ohana
//
//  Created by Guanchenulous on 10.03.26.
//

import SwiftUI

struct HomeBentoBoxes: View {
    let islandLevel: IslandLevel
    let pets: [Pet]
    var onOasisTap: (() -> Void)? = nil
    var onStreakTap: (() -> Void)? = nil

    @AppStorage("user_login_streak") private var loginStreak: Int = 0
    @AppStorage("user_last_login_date") private var lastLoginDateStr: String = ""
    @AppStorage("user_login_history") private var loginHistoryJSON: String = ""
    
    private let treeMgr = OasisTreeManager.shared

    var body: some View {
        HStack(spacing: 12) {
            // 生命之树
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onOasisTap?()
            } label: {
                BentoStatCard(
                    icon: "leaf.fill",
                    title: "生命之树",
                    value: "Lv.\(treeMgr.treeLevel.rawValue)",
                    unit: "",
                    trend: treeMgr.treeLevel.displayName,
                    trendUp: true,
                    accentColor: .goLime,
                    showMiniBar: treeMgr.treeLevel.rawValue,
                    barMax: 10
                )
            }
            .buttonStyle(.plain)

            // 打卡连击（用户每日开App即打卡）
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onStreakTap?()
            } label: {
                BentoStatCard(
                    icon: "flame.fill",
                    title: "打卡连击",
                    value: "\(loginStreak)",
                    unit: "天",
                    trend: loginStreak >= 7 ? "🔥 火热连击！" : "继续保持！",
                    trendUp: true,
                    accentColor: .goOrange,
                    showMiniBar: min(7, loginStreak),
                    barMax: 7
                )
            }
            .buttonStyle(.plain)
            .onAppear { refreshLoginStreak() }
        }
    }

    private func refreshLoginStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        let todayStr = formatter.string(from: today)
        
        // 如果今天已经登录过，不重复计算
        guard lastLoginDateStr != todayStr else { return }
        
        if !lastLoginDateStr.isEmpty,
           let lastLogin = formatter.date(from: lastLoginDateStr) {
            let lastLoginDay = calendar.startOfDay(for: lastLogin)
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
            
            if calendar.isDate(lastLoginDay, inSameDayAs: yesterday) {
                // 昨天登录，连续登录
                loginStreak += 1
            } else if lastLoginDay < yesterday {
                // 超过1天没登录，重置连击
                loginStreak = 1
            }
            // 如果 lastLoginDay > yesterday（未来日期），保持当前连击不变
        } else {
            // 首次登录
            loginStreak = 1
        }
        
        lastLoginDateStr = todayStr
        appendLoginHistory(todayStr: todayStr, fmt: formatter)
    }

    private func appendLoginHistory(todayStr: String, fmt: DateFormatter) {
        var history: [String] = []
        if !loginHistoryJSON.isEmpty,
           let data = loginHistoryJSON.data(using: .utf8),
           let arr = try? JSONDecoder().decode([String].self, from: data) {
            history = arr
        }
        if !history.contains(todayStr) {
            history.append(todayStr)
            // 只保留最近 365 条
            if history.count > 365 { history = Array(history.suffix(365)) }
            if let data = try? JSONEncoder().encode(history),
               let str = String(data: data, encoding: .utf8) {
                loginHistoryJSON = str
            }
        }
    }
}
