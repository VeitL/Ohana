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
            nextLevelThreshold: treeVisualNextLevelThreshold,
            progressToNextLevel: CGFloat(treeVisualProgressToNextLevel),
            passiveIncomeAmount: treePassiveIncomeAmount,
            memberCount: humans.count + pets.count,
            localization: l
        )
    }

    // MARK: - Inject Energy Button

    var injectEnergyButton: some View {
        let canInject = canInjectTreeEnergy
        return Button {
            injectTreeEnergy()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill") // a11y: allow decorative action icon paired with label
                    .accessibilityHidden(true)
                Text(l.tr(zh: "注入能量", en: "Inject energy", de: "Energie geben"))
                    .font(OhanaFont.headline(.black))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                Text("(-80🥥)")
                    .font(OhanaFont.subheadline(.bold))
                    .foregroundStyle(Color.ohanaPrimaryActionText.opacity(0.55))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                canInject ? Color.goPrimary : Color.ohanaControlFill,
                in: Capsule()
            )
            .overlay(Capsule().strokeBorder(
                canInject ? Color.clear : Color.ohanaPrimaryText.opacity(0.08),
                lineWidth: 1
            ))
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!canInject)
        .opacity(canInject ? 1 : 0.45)
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
        CheckInStreakStore.currentStreak(for: currentActiveHumanId)
    }

    var longestStreak: Int {
        CheckInStreakStore.longestStreak(for: currentActiveHumanId)
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
            crittersLockedLevel: lockedLevel(requiredLevel: critterUnlockLevel),
            gachaLockedLevel: lockedLevel(requiredLevel: gachaUnlockLevel),
            onOpenShop: {
                openSheet(.coconutShop(.effect))
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
