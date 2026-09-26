//
//  AchievementWallContentView+Rewards.swift
//  Ohana
//

import SwiftUI
import UIKit

extension AchievementWallContentView {
    func rewardState(for badge: Achievement) -> AchievementRewardState {
        guard badge.isUnlocked else { return .locked }
        if isRewardClaimed(badge) { return .claimed }
        return .claimable
    }

    func sortRank(for badge: Achievement) -> Int {
        switch rewardState(for: badge) {
        case .claimable: 0
        case .unlocked: 1
        case .claimed: 2
        case .locked: 3
        }
    }

    func statusTitle(for state: AchievementRewardState) -> String {
        switch state {
        case .claimable: l.tr(zh: "可领取", en: "Ready to claim", de: "Bereit")
        case .claimed: l.tr(zh: "已领取", en: "Claimed", de: "Abgeholt")
        case .unlocked: l.tr(zh: "已解锁", en: "Unlocked", de: "Freigeschaltet")
        case .locked: l.tr(zh: "进行中", en: "In progress", de: "In Arbeit")
        }
    }

    func rewardKey(for badge: Achievement) -> String {
        if screenModel.isGlobalAchievement(badge) {
            return "global::\(badge.id)"
        }
        if let human = activeHuman {
            return "\(human.id.uuidString)_\(badge.id)"
        }
        return "\(activePet.id.uuidString)_\(badge.id)"
    }

    var claimedRewardIDs: Set<String> {
        Set(claimedRewardRaw.split(separator: ",").map(String.init))
    }

    func isRewardClaimed(_ badge: Achievement) -> Bool {
        let key = rewardKey(for: badge)
        return claimedRewardIDs.contains(key)
            || achievementSnapshot.items.contains { $0.achievementKey == key && $0.isClaimed }
    }

    func claimReward(for badge: Achievement) {
        guard badge.isUnlocked, !isRewardClaimed(badge) else { return }
        let claim = rewardClaim(for: badge)
        let claimedRaw = claimedRewardRaw
        let targetHuman = activeHuman
        let targetPet = activePet
        let entityID = targetHuman?.id ?? targetPet.id
        let entityKind = targetHuman == nil ? EntityKind.pet.rawValue : EntityKind.human.rawValue
        commandQueue.enqueue(.achievementReward(entityID: entityID, kind: entityKind, badgeIDs: [badge.id])) {
            let result = RewardEconomyCommandExecutor(context: modelContext, services: appServices).claimAchievementRewards(
                [claim],
                claimedRewardRaw: claimedRaw,
                amountPerBadge: rewardPerAchievement,
                human: targetHuman,
                pet: targetPet,
                note: "achievement.reward.claim"
            )
            handleAchievementRewardResult(result)
        }
    }

    func claimAllRewards() {
        let badges = claimable
        guard !badges.isEmpty else { return }
        let claims = badges.map(rewardClaim(for:))
        let claimedRaw = claimedRewardRaw
        let targetHuman = activeHuman
        let targetPet = activePet
        let entityID = targetHuman?.id ?? targetPet.id
        let entityKind = targetHuman == nil ? EntityKind.pet.rawValue : EntityKind.human.rawValue
        commandQueue.enqueue(.achievementReward(entityID: entityID, kind: entityKind, badgeIDs: badges.map(\.id))) {
            let result = RewardEconomyCommandExecutor(context: modelContext, services: appServices).claimAchievementRewards(
                claims,
                claimedRewardRaw: claimedRaw,
                amountPerBadge: rewardPerAchievement,
                human: targetHuman,
                pet: targetPet,
                note: "achievement.reward.claimAll"
            )
            handleAchievementRewardResult(result)
        }
    }

    func rewardClaim(for badge: Achievement) -> AchievementRewardClaim {
        AchievementRewardClaim(
            badgeID: badge.id,
            rewardKey: rewardKey(for: badge),
            emoji: badge.emoji,
            logTitle: l.tr(
                zh: "成就奖励 · \(badge.title)",
                en: "Badge reward · \(badge.title)",
                de: "Abzeichen-Belohnung · \(badge.title)"
            ),
            isUnlocked: badge.isUnlocked
        )
    }

    func handleAchievementRewardResult(_ result: AchievementRewardCommandResult) {
        guard result.didClaim else { return }
        claimedRewardRaw = result.updatedClaimedRewardRaw
        showReward(
            result.totalAmount,
            label: l.tr(
                zh: "成就奖励",
                en: "Badge reward",
                de: "Abzeichen-Belohnung"
            )
        )
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func showReward(_ amount: Int, label: String?) {
        guard amount > 0 else { return }
        rewardAnimationAmount = amount
        rewardAnimationLabel = label
        showRewardAnimation = false
        DispatchQueue.main.async {
            showRewardAnimation = true
        }
    }
}
