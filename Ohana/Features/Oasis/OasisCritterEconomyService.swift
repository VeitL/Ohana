//
//  OasisCritterEconomyService.swift
//  Ohana
//
//  Coconut wallet integration for Oasis critter rewards and costs.
//

import Foundation
import SwiftData

enum OasisRewardWriteError: LocalizedError {
    case coconutAwardFailed

    var errorDescription: String? {
        switch self {
        case .coconutAwardFailed:
            "Oasis coconut reward could not be saved."
        }
    }
}

@MainActor
enum OasisCritterEconomyService {
    static func currentHuman(
        context: ModelContext,
        activeHumanSelection: ActiveHumanSelecting = UserDefaultsActiveHumanSelection()
    ) -> Human? {
        guard let id = activeHumanSelection.currentHumanId else { return nil }
        guard let uuid = UUID(uuidString: id) else {
            OhanaLog.warning(
                "[OasisCritterEconomyService] active human id is invalid: \(id)",
                category: "Oasis"
            )
            return nil
        }
        var descriptor = FetchDescriptor<Human>(
            predicate: #Predicate<Human> { human in
                human.id == uuid
            }
        )
        descriptor.fetchLimit = 1
        do {
            return try context.fetch(descriptor).first
        } catch {
            OhanaLog.warning(
                "[OasisCritterEconomyService] failed to fetch active human id=\(id): \(error.localizedDescription)",
                category: "Oasis"
            )
            return nil
        }
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
        if let human = currentHuman(context: context, activeHumanSelection: activeHumanSelection) {
            return CoconutWalletService.balance(for: human, context: context)
        }
        return CoconutWalletService.legacySystemBalance(context: context, fallback: questManager.coconutCount)
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
            return CoconutWalletService.balance(for: human, context: context) >= amount
        }
        return CoconutWalletService.legacySystemBalance(context: context, fallback: questManager.coconutCount) >= amount
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
        questManager: QuestManager,
        updatesProjection: Bool = true
    ) -> Bool {
        guard amount > 0 else { return true }
        if let human = currentHuman(context: context, activeHumanSelection: activeHumanSelection) {
            guard CoconutWalletService.balance(for: human, context: context) >= amount else { return false }
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
                    updatesProjection: updatesProjection,
                    projectionManager: questManager
                )
                return true
            } catch {
                #if DEBUG
                    OhanaLog.error("[OasisCritterEconomyService] spend failed: \(error.localizedDescription)", category: "Oasis")
                #endif
                return false
            }
        }
        guard CoconutWalletService.legacySystemBalance(context: context, fallback: questManager.coconutCount) >= amount else { return false }
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
                updatesProjection: updatesProjection,
                projectionManager: questManager
            )
            return true
        } catch {
            #if DEBUG
                OhanaLog.error("[OasisCritterEconomyService] system spend failed: \(error.localizedDescription)", category: "Oasis")
            #endif
            return false
        }
    }

    @discardableResult
    static func awardCurrentHumanCoconuts(
        _ amount: Int,
        emoji: String,
        title: String,
        context: ModelContext,
        postsRewardFeedback: Bool = true
    ) -> Bool {
        guard amount > 0 else { return true }
        return awardCurrentHumanCoconuts(
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

    @discardableResult
    static func awardCurrentHumanCoconuts(
        _ amount: Int,
        emoji: String,
        title: String,
        context: ModelContext,
        postsRewardFeedback: Bool = true,
        activeHumanSelection: ActiveHumanSelecting,
        wallet: CoconutWalletManaging,
        questManager: QuestManager
    ) -> Bool {
        guard amount > 0 else { return true }
        if let human = currentHuman(context: context, activeHumanSelection: activeHumanSelection) {
            do {
                try wallet.apply(
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
                return true
            } catch {
                #if DEBUG
                    OhanaLog.error("[OasisCritterEconomyService] human award failed: \(error.localizedDescription)", category: "Oasis")
                #endif
                return false
            }
        } else {
            do {
                try wallet.apply(
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
                return true
            } catch {
                #if DEBUG
                    OhanaLog.error("[OasisCritterEconomyService] system award failed: \(error.localizedDescription)", category: "Oasis")
                #endif
                return false
            }
        }
    }
}
