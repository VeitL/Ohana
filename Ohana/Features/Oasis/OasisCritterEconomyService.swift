//
//  OasisCritterEconomyService.swift
//  Ohana
//
//  Coconut wallet integration for Oasis critter rewards and costs.
//

import Foundation
import SwiftData

@MainActor
enum OasisCritterEconomyService {
    static func currentHuman(
        context: ModelContext,
        activeHumanSelection: ActiveHumanSelecting = UserDefaultsActiveHumanSelection()
    ) -> Human? {
        guard let id = activeHumanSelection.currentHumanId else { return nil }
        return (try? context.fetch(FetchDescriptor<Human>()))?.first { $0.id.uuidString == id }
    }

    static func currentHumanBalance(context: ModelContext) -> Int {
        currentHumanBalance(
            context: context,
            activeHumanSelection: UserDefaultsActiveHumanSelection(),
            questManager: QuestManager()
        )
    }

    static func currentHumanBalance(
        context: ModelContext,
        activeHumanSelection: ActiveHumanSelecting,
        questManager: QuestManager
    ) -> Int {
        currentHuman(context: context, activeHumanSelection: activeHumanSelection)?.coconutBalance ?? questManager.coconutCount
    }

    static func canSpendCurrentHumanCoconuts(_ amount: Int, context: ModelContext) -> Bool {
        canSpendCurrentHumanCoconuts(
            amount,
            context: context,
            activeHumanSelection: UserDefaultsActiveHumanSelection(),
            questManager: QuestManager()
        )
    }

    static func canSpendCurrentHumanCoconuts(
        _ amount: Int,
        context: ModelContext,
        activeHumanSelection: ActiveHumanSelecting,
        questManager: QuestManager
    ) -> Bool {
        guard amount > 0 else { return true }
        if let human = currentHuman(context: context, activeHumanSelection: activeHumanSelection) {
            return human.coconutBalance >= amount
        }
        return questManager.coconutCount >= amount
    }

    @discardableResult
    static func spendCurrentHumanCoconuts(_ amount: Int, emoji: String, title: String, context: ModelContext) -> Bool {
        spendCurrentHumanCoconuts(
            amount,
            emoji: emoji,
            title: title,
            context: context,
            activeHumanSelection: UserDefaultsActiveHumanSelection(),
            wallet: SwiftDataCoconutWalletManager(),
            questManager: QuestManager()
        )
    }

    @discardableResult
    static func spendCurrentHumanCoconuts(
        _ amount: Int,
        emoji: String,
        title: String,
        context: ModelContext,
        activeHumanSelection: ActiveHumanSelecting,
        wallet: CoconutWalletManaging,
        questManager: QuestManager
    ) -> Bool {
        guard amount > 0 else { return true }
        if let human = currentHuman(context: context, activeHumanSelection: activeHumanSelection) {
            guard human.coconutBalance >= amount else { return false }
            do {
                try wallet.apply(
                    deltas: [
                        .human(
                            human,
                            delta: -amount,
                            entryKind: .spend,
                            source: .oasis,
                            title: title,
                            emoji: emoji,
                            actorId: human.id.uuidString,
                            actorName: human.name,
                            subjectKind: .system,
                            subjectId: nil
                        )
                    ],
                    context: context,
                    save: false,
                    postsRewardFeedback: true,
                    updatesProjection: true,
                    projectionManager: questManager
                )
                return true
            } catch {
                #if DEBUG
                print("❌ [OasisCritterEconomyService] spend failed: \(error.localizedDescription)")
                #endif
                return false
            }
        }
        guard questManager.coconutCount >= amount else { return false }
        do {
            try wallet.apply(
                deltas: [
                    .system(
                        delta: -amount,
                        entryKind: .spend,
                        source: .oasis,
                        title: title,
                        emoji: emoji,
                        actorId: "system",
                        actorName: "Oasis"
                    )
                ],
                context: context,
                save: false,
                postsRewardFeedback: true,
                updatesProjection: true,
                projectionManager: questManager
            )
            return true
        } catch {
            #if DEBUG
            print("❌ [OasisCritterEconomyService] system spend failed: \(error.localizedDescription)")
            #endif
            return false
        }
    }

    static func awardCurrentHumanCoconuts(
        _ amount: Int,
        emoji: String,
        title: String,
        context: ModelContext,
        postsRewardFeedback: Bool = true
    ) {
        guard amount > 0 else { return }
        awardCurrentHumanCoconuts(
            amount,
            emoji: emoji,
            title: title,
            context: context,
            postsRewardFeedback: postsRewardFeedback,
            activeHumanSelection: UserDefaultsActiveHumanSelection(),
            wallet: SwiftDataCoconutWalletManager(),
            questManager: QuestManager()
        )
    }

    static func awardCurrentHumanCoconuts(
        _ amount: Int,
        emoji: String,
        title: String,
        context: ModelContext,
        postsRewardFeedback: Bool = true,
        activeHumanSelection: ActiveHumanSelecting,
        wallet: CoconutWalletManaging,
        questManager: QuestManager
    ) {
        guard amount > 0 else { return }
        if let human = currentHuman(context: context, activeHumanSelection: activeHumanSelection) {
            _ = try? wallet.apply(
                deltas: [
                    .human(
                        human,
                        delta: amount,
                        entryKind: .reward,
                        source: .oasis,
                        title: title,
                        emoji: emoji,
                        actorId: human.id.uuidString,
                        actorName: human.name,
                        subjectKind: .system,
                        subjectId: nil
                    )
                ],
                context: context,
                save: false,
                postsRewardFeedback: postsRewardFeedback,
                updatesProjection: true,
                projectionManager: questManager
            )
        } else {
            _ = try? wallet.apply(
                deltas: [
                    .system(
                        delta: amount,
                        entryKind: .reward,
                        source: .oasis,
                        title: title,
                        emoji: emoji,
                        actorId: "system",
                        actorName: "Oasis"
                    )
                ],
                context: context,
                save: false,
                postsRewardFeedback: postsRewardFeedback,
                updatesProjection: true,
                projectionManager: questManager
            )
        }
    }
}
