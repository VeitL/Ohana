//
//  OasisRewardView+CardsAndCheckIn.swift
//  Ohana
//

import SwiftUI

extension OasisRewardView {
    // MARK: - Progress Card

    var progressCard: some View {
        OasisProgressCard(
            totalEnergy: treeVisualTotalEnergy,
            careGrowthEnergy: treeMgr.careGrowthEnergy,
            injectedEnergy: treeMgr.injectedEnergy,
            nextLevelThreshold: treeVisualNextLevelThreshold,
            progressToNextLevel: CGFloat(treeVisualProgressToNextLevel),
            passiveIncomeAmount: treePassiveIncomeAmount,
            memberCount: humans.count + pets.count,
            localization: l
        )
    }

    // MARK: - Milestone Card

    var milestoneCard: some View {
        OasisMilestoneCard(treeLevel: treeVisualLevel, localization: l)
    }

    // MARK: - 模块六：打卡日历（完整月视图）

    var checkInCalendarCard: some View {
        OasisCheckInCalendarCard(
            displayMonth: $calendarDisplayMonth,
            checkedInDates: checkedInDates,
            makeupDates: makeupDates,
            makeupPackCount: makeupPackCount,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            monthCheckInRate: monthCheckInRate,
            lastClaimedMilestone: lastClaimedMilestone,
            localization: l,
            makeupShopLockedLevel: lockedLevel(requiredLevel: shopUnlockLevel),
            onRequestMakeup: { date in
                confirmationRoute = .makeup(date: date)
            },
            onOpenMakeupShop: {
                openSheet(.coconutShop(.boost))
            },
            onClaimMilestone: claimMilestone
        )
    }

    // MARK: - 打卡工具函数

    var currentStreak: Int {
        0
    }

    var longestStreak: Int {
        0
    }

    var monthCheckInRate: Int {
        let cal = Calendar.current
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let today = Date()
        let comps = cal.dateComponents([.year, .month], from: today)
        guard let firstOfMonth = cal.date(from: comps) else { return 0 }
        let dayOfMonth = cal.component(.day, from: today)
        var count = 0
        for d in 0 ..< dayOfMonth {
            if let date = cal.date(byAdding: .day, value: d, to: firstOfMonth) {
                let s = fmt.string(from: date)
                if checkedInDates.contains(s) { count += 1 }
            }
        }
        return dayOfMonth > 0 ? Int(Double(count) / Double(dayOfMonth) * 100) : 0
    }

    func loadCheckInData() {
        applyCheckInSnapshot(commandExecutor.loadCheckInData(currentActiveHumanId: currentActiveHumanId))
    }

    func triggerTodayCheckIn() {
        if let updatedDates = commandExecutor.triggerTodayCheckIn(
            currentActiveHumanId: currentActiveHumanId,
            checkedInDates: checkedInDates
        ) {
            checkedInDates = updatedDates
            rebuildOasisRenderSnapshots()
        }
    }

    func scheduleTodayCheckIn() {
        checkInCommandTask?.cancel()
        checkInCommandTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 140) {
            guard isEmbeddedActive else {
                checkInCommandTask = nil
                return
            }
            triggerTodayCheckIn()
            checkInCommandTask = nil
        }
    }

    func applyMakeup(date: String) {
        let snapshot = OasisCheckInSnapshot(
            checkedInDates: checkedInDates,
            makeupDates: makeupDates,
            makeupPackCount: makeupPackCount,
            lastClaimedMilestone: lastClaimedMilestone
        )
        guard let updated = commandExecutor.applyMakeup(
            date: date,
            currentActiveHumanId: currentActiveHumanId,
            snapshot: snapshot
        ) else { return }
        applyCheckInSnapshot(updated)
        OhanaFeedback.medium()
    }

    func claimMilestone(_ days: Int, reward: Int, emoji: String) {
        lastClaimedMilestone = days
        OhanaFeedback.success()
        checkInCommandTask?.cancel()
        checkInCommandTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 70) {
            commandExecutor.claimMilestone(
                days: days,
                reward: reward,
                emoji: emoji,
                currentActiveHumanId: currentActiveHumanId
            )
            rebuildOasisRenderSnapshots()
            checkInCommandTask = nil
        }
    }

    func applyCheckInSnapshot(_ snapshot: OasisCheckInSnapshot) {
        checkedInDates = snapshot.checkedInDates
        makeupDates = snapshot.makeupDates
        makeupPackCount = snapshot.makeupPackCount
        lastClaimedMilestone = snapshot.lastClaimedMilestone
    }

    // MARK: - Bento Grid

    var oasisBentoGrid: some View {
        OasisBentoGridView(
            snapshot: bentoSnapshot,
            localization: l,
            shopLockedLevel: lockedLevel(requiredLevel: shopUnlockLevel),
            achievementsLockedLevel: lockedLevel(requiredLevel: achievementUnlockLevel),
            crittersLockedLevel: lockedLevel(requiredLevel: critterUnlockLevel),
            gachaLockedLevel: lockedLevel(requiredLevel: gachaUnlockLevel),
            isCompact: hideToolbar,
            onShowFeatureInfo: { info in
                withAnimation(GoMotion.stateChange) {
                    activeBentoFeatureInfo = info
                }
            },
            onOpenShop: {
                let category: ShopItem.ShopCategory = plantAmbienceSnapshot.isYieldAmbienceUnlocked || plantAmbienceSnapshot.lushnessLevel > 0
                    ? .plantDecor
                    : .effect
                openSheet(.coconutShop(category))
            },
            onOpenAchievements: {
                openSheet(.achievements)
            },
            onOpenCritters: {
                openSheet(.critterCodex)
            },
            onOpenGacha: {
                openSheet(.gacha)
            }
        )
    }
}
