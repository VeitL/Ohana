//
//  HomeBentoBoxes.swift
//  Ohana
//
//  Created by Guanchenulous on 10.03.26.
//

import SwiftUI

struct HomeBentoBoxes: View {
    let pets: [Pet]
    var onOasisTap: (() -> Void)? = nil
    var onStreakTap: (() -> Void)? = nil

    @State private var checkInStreak: Int = 0
    private let checkedInKey = "oasis_checkedIn_dates"
    private let questMgr = QuestManager.shared

    var body: some View {
        HStack(spacing: 12) {
            // 椰子余额（替代重复的生命之树信息，HomeHighlightDeck 已展示等级）
            BentoStatCard(
                icon: "leaf.fill",
                title: "椰子余额",
                value: "\(questMgr.coconutCount)",
                unit: "🥥",
                trend: "完成委托获取",
                trendUp: true,
                accentColor: .goYellow,
                showMiniBar: 0,
                barMax: 0
            )

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
