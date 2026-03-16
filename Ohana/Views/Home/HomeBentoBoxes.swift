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

    @State private var checkInStreak: Int = 0
    private let checkedInKey = "oasis_checkedIn_dates"
    
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
                    value: "\(checkInStreak)",
                    unit: "天",
                    trend: checkInStreak >= 7 ? "🔥 火热连击！" : "继续保持！",
                    trendUp: true,
                    accentColor: .goOrange,
                    showMiniBar: min(7, checkInStreak),
                    barMax: 7
                )
            }
            .buttonStyle(.plain)
        }
        .onAppear { refreshCheckInStreak() }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            refreshCheckInStreak()
        }
    }

    private func refreshCheckInStreak() {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current

        let checkedInDates = Set(UserDefaults.standard.stringArray(forKey: checkedInKey) ?? [])
        var streak = 0
        var day = Date()
        while true {
            let dayStr = formatter.string(from: day)
            if checkedInDates.contains(dayStr) {
                streak += 1
                guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
                day = prev
            } else {
                break
            }
        }
        checkInStreak = streak
    }
}
