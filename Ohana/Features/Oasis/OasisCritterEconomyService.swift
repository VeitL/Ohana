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
    case persistenceFailed(String)

    var errorDescription: String? {
        switch self {
        case .coconutAwardFailed:
            "Oasis coconut reward could not be saved."
        case let .persistenceFailed(message):
            "Oasis reward changes could not be saved: \(message)"
        }
    }
}

@MainActor
enum OasisCritterEconomyService {
    private enum InjectionFundingSource {
        case island(CoconutAccount)
        case human(Human, CoconutAccount)
        case pet(Pet, CoconutAccount)

        var availableBalance: Int {
            switch self {
            case let .island(account), let .human(_, account), let .pet(_, account):
                max(0, account.balance)
            }
        }

        var accountKey: String {
            switch self {
            case let .island(account), let .human(_, account), let .pet(_, account):
                account.accountKey
            }
        }

        func debitDelta(
            amount: Int,
            emoji: String,
            title: String,
            sourceModelId: String,
            transactionKey: String,
            occurredAt: Date
        ) -> CoconutWalletDelta {
            let metadataJSON = "{\"walletScope\":\"islandTotal\",\"oasisInjection\":true}"
            switch self {
            case .island:
                return CoconutWalletDelta.island(
                    delta: -amount,
                    entryKind: .spend,
                    source: .oasis,
                    title: title,
                    emoji: emoji,
                    sourceModelName: "OasisTreeInjection",
                    sourceModelId: sourceModelId,
                    metadataJSON: metadataJSON,
                    occurredAt: occurredAt,
                    transactionKey: transactionKey
                )
            case let .human(human, _):
                return CoconutWalletDelta.human(
                    human,
                    delta: -amount,
                    entryKind: .spend,
                    source: .oasis,
                    title: title,
                    emoji: emoji,
                    subjectKind: .household,
                    subjectId: "island",
                    sourceModelName: "OasisTreeInjection",
                    sourceModelId: sourceModelId,
                    metadataJSON: metadataJSON,
                    occurredAt: occurredAt,
                    transactionKey: transactionKey
                )
            case let .pet(pet, _):
                return CoconutWalletDelta.pet(
                    pet,
                    delta: -amount,
                    entryKind: .spend,
                    source: .oasis,
                    title: title,
                    emoji: emoji,
                    subjectKind: .household,
                    subjectId: "island",
                    sourceModelName: "OasisTreeInjection",
                    sourceModelId: sourceModelId,
                    metadataJSON: metadataJSON,
                    occurredAt: occurredAt,
                    transactionKey: transactionKey
                )
            }
        }
    }

    private struct InjectionFundingContribution {
        let source: InjectionFundingSource
        let amount: Int
    }

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
            let human = try context.fetch(descriptor).first
            if let human,
               !MemberLifecycleGate.disposition(human: human, writeKind: .care).allowsEconomyDerivation {
                OhanaLog.warning(
                    "[OasisCritterEconomyService] active human id=\(id) is memorialized; skipping Oasis wallet access",
                    category: "Oasis"
                )
                return nil
            }
            return human
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
        _ = questManager
        if let human = currentHuman(context: context, activeHumanSelection: activeHumanSelection) {
            return CoconutWalletService.balance(for: human, context: context)
        }
        return 0
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
        _ = questManager
        guard let human = currentHuman(context: context, activeHumanSelection: activeHumanSelection) else {
            return false
        }
        guard amount > 0 else { return true }
        return CoconutWalletService.balance(for: human, context: context) >= amount
    }

    static func availableCoconutBalance(context: ModelContext) -> Int {
        CoconutWalletService.totalBalance(context: context)
    }

    static func canSpendAvailableCoconuts(_ amount: Int, context: ModelContext) -> Bool {
        amount <= 0 || availableCoconutBalance(context: context) >= amount
    }

    @discardableResult
    static func spendAvailableCoconuts(
        _ amount: Int,
        emoji: String,
        title: String,
        context: ModelContext,
        activeHumanSelection: ActiveHumanSelecting = UserDefaultsActiveHumanSelection(),
        wallet providedWallet: CoconutWalletManaging? = nil,
        questManager providedQuestManager: QuestManager? = nil,
        updatesProjection: Bool = true
    ) -> Bool {
        guard amount > 0 else { return true }
        let wallet = providedWallet ?? SwiftDataCoconutWalletManager()
        let questManager = providedQuestManager ?? QuestManager()
        let fundingSources = injectionFundingSources(
            context: context,
            activeHumanSelection: activeHumanSelection
        )
        var remaining = amount
        var contributions: [InjectionFundingContribution] = []
        for source in fundingSources where remaining > 0 {
            let contribution = min(remaining, source.availableBalance)
            guard contribution > 0 else { continue }
            contributions.append(InjectionFundingContribution(source: source, amount: contribution))
            remaining -= contribution
        }
        guard remaining == 0 else { return false }

        let transactionID = UUID().uuidString
        let occurredAt = Date()
        let deltas = contributions.map { contribution in
            contribution.source.debitDelta(
                amount: contribution.amount,
                emoji: emoji,
                title: title,
                sourceModelId: transactionID,
                transactionKey: "oasis:treeInjection:\(transactionID):\(contribution.source.accountKey)",
                occurredAt: occurredAt
            )
        }
        do {
            try wallet.apply(
                deltas: deltas,
                context: context,
                save: false,
                postsRewardFeedback: true,
                updatesProjection: updatesProjection,
                projectionManager: questManager
            )
            return true
        } catch {
            #if DEBUG
                OhanaLog.error(
                    "[OasisCritterEconomyService] aggregate spend failed: \(error.localizedDescription)",
                    category: "Oasis"
                )
            #endif
            return false
        }
    }

    private static func injectionFundingSources(
        context: ModelContext,
        activeHumanSelection: ActiveHumanSelecting
    ) -> [InjectionFundingSource] {
        let selectedHumanID = activeHumanSelection.currentHumanId ?? ""
        let accounts: [CoconutAccount]
        do {
            accounts = try context.fetch(
                FetchDescriptor<CoconutAccount>(
                    predicate: #Predicate<CoconutAccount> { $0.balance > 0 },
                    sortBy: [SortDescriptor(\CoconutAccount.createdAt, order: .forward)]
                )
            )
        } catch {
            OhanaLog.warning(
                "[OasisCritterEconomyService] failed to fetch injection funding accounts: \(error.localizedDescription)",
                category: "Oasis"
            )
            return []
        }

        let orderedAccounts = accounts.sorted { lhs, rhs in
            let lhsPriority = injectionFundingPriority(account: lhs, selectedHumanID: selectedHumanID)
            let rhsPriority = injectionFundingPriority(account: rhs, selectedHumanID: selectedHumanID)
            if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
            return lhs.accountKey < rhs.accountKey
        }
        return orderedAccounts.compactMap { account in
            injectionFundingSource(account: account, context: context)
        }
    }

    private static func injectionFundingPriority(account: CoconutAccount, selectedHumanID: String) -> Int {
        if account.accountKey == CoconutAccountKey.islandReserve { return 0 }
        if account.ownerKind == .human, account.ownerId == selectedHumanID { return 1 }
        return 2
    }

    private static func injectionFundingSource(
        account: CoconutAccount,
        context: ModelContext
    ) -> InjectionFundingSource? {
        if account.ownerKind == .system {
            return account.accountKey == CoconutAccountKey.islandReserve ? .island(account) : nil
        }
        guard let ownerID = UUID(uuidString: account.ownerId) else {
            return nil
        }
        switch account.ownerKind {
        case .human:
            var descriptor = FetchDescriptor<Human>(predicate: #Predicate<Human> { $0.id == ownerID })
            descriptor.fetchLimit = 1
            guard let humans = try? context.fetch(descriptor),
                  let human = humans.first,
                  EconomyWalletWritePolicy.canWrite(human) else { return nil }
            return .human(human, account)
        case .pet:
            var descriptor = FetchDescriptor<Pet>(predicate: #Predicate<Pet> { $0.id == ownerID })
            descriptor.fetchLimit = 1
            guard let pets = try? context.fetch(descriptor),
                  let pet = pets.first,
                  EconomyWalletWritePolicy.canWrite(pet) else { return nil }
            return .pet(pet, account)
        case .system:
            return nil
        }
    }

    @discardableResult
    static func awardBudgetedCurrentHumanCoconuts(
        _ amount: Int,
        emoji: String,
        title: String,
        context: ModelContext,
        postsRewardFeedback: Bool = true,
        date: Date = Date()
    ) -> Int? {
        awardBudgetedCurrentHumanCoconuts(
            amount,
            emoji: emoji,
            title: title,
            context: context,
            postsRewardFeedback: postsRewardFeedback,
            activeHumanSelection: UserDefaultsActiveHumanSelection(),
            wallet: SwiftDataCoconutWalletManager(),
            questManager: QuestManager(),
            date: date
        )
    }

    @discardableResult
    static func awardBudgetedCurrentHumanCoconuts(
        _ amount: Int,
        emoji: String,
        title: String,
        context: ModelContext,
        postsRewardFeedback: Bool = true,
        activeHumanSelection: ActiveHumanSelecting,
        wallet: CoconutWalletManaging,
        questManager: QuestManager,
        date: Date = Date()
    ) -> Int? {
        guard let human = currentHuman(context: context, activeHumanSelection: activeHumanSelection) else {
            return nil
        }
        guard amount > 0 else { return 0 }

        let action = QuestManager.OhanaActionType.general(
            humanReward: amount,
            petReward: 0,
            emoji: emoji,
            title: title
        )
        let wasOnCooldown = questManager.isOnCooldown(petId: nil, type: action)
        let householdKey = CoconutEconomyPolicyV2.householdBudgetKey(context: context)
        let memberKey = human.id.uuidString
        let result = CoconutEconomyPolicyV2.reward(
            for: action,
            quality: .none,
            isOnCooldown: wasOnCooldown,
            userKey: householdKey,
            memberKey: memberKey,
            careObjectKeys: [],
            careObjectCount: CoconutEconomyPolicyV2.careObjectCount(context: context),
            hasHumanAccount: true,
            hasPetAccount: false,
            date: date,
            forcedLuck: EconomyLuckTier.none,
            context: context
        )
        questManager.lastEconomyRewardResult = result

        let awarded = result.humanCoconuts
        let walletDeltas: [CoconutWalletDelta] = awarded > 0
            ? [
                .human(
                    human,
                    delta: awarded,
                    entryKind: .reward,
                    source: .oasis,
                    title: title,
                    emoji: emoji,
                    actorId: human.id.uuidString,
                    actorName: human.name,
                    subjectKind: .human,
                    subjectId: human.id.uuidString,
                    metadataJSON: result.metadataJSON,
                    occurredAt: date
                )
            ]
            : []

        do {
            try wallet.apply(
                deltas: walletDeltas,
                context: context,
                save: false,
                postsRewardFeedback: false,
                updatesProjection: true,
                projectionManager: questManager
            )
            EconomyDailyBudgetStore.commit(
                result,
                householdKey: householdKey,
                memberKey: memberKey,
                careObjectKeys: [],
                date: date,
                context: context,
                save: false,
                writeDefaults: false
            )
            try saveCritterEconomyChanges(context: context)
            EconomyDailyBudgetStore.commit(
                result,
                householdKey: householdKey,
                memberKey: memberKey,
                careObjectKeys: [],
                date: date,
                context: nil,
                save: false
            )
            if postsRewardFeedback {
                questManager.postEconomyFeedback(
                    result,
                    type: action,
                    title: title,
                    actorId: human.id.uuidString,
                    actorName: human.name
                )
            }
            if !wasOnCooldown {
                questManager.recordCooldown(petId: nil, type: action)
            }
            return awarded
        } catch {
            context.rollback()
            questManager.lastEconomyRewardResult = .empty
            wallet.refreshQuestProjection(context: context, manager: questManager)
            #if DEBUG
                OhanaLog.error("[OasisCritterEconomyService] budgeted award failed: \(error.localizedDescription)", category: "Oasis")
            #endif
            return nil
        }
    }

    @discardableResult
    static func awardSpecialCurrentHumanCoconuts(
        _ amount: Int,
        emoji: String,
        title: String,
        sourceModelName: String,
        sourceModelId: String,
        transactionKey: String,
        metadataJSON: String = "",
        context: ModelContext,
        postsRewardFeedback: Bool = true,
        activeHumanSelection: ActiveHumanSelecting,
        wallet: CoconutWalletManaging,
        questManager: QuestManager,
        occurredAt: Date = Date()
    ) -> Int? {
        guard let human = currentHuman(context: context, activeHumanSelection: activeHumanSelection) else {
            return nil
        }
        guard amount > 0 else { return 0 }
        do {
            let awarded = try questManager.stageSpecialCoconutReward(
                amount: amount,
                emoji: emoji,
                title: title,
                actorId: human.id.uuidString,
                actorName: human.name,
                source: .oasis,
                sourceModelName: sourceModelName,
                sourceModelId: sourceModelId,
                metadataJSON: metadataJSON,
                transactionKey: transactionKey,
                context: context,
                occurredAt: occurredAt,
                postsRewardFeedback: postsRewardFeedback
            )
            try saveCritterEconomyChanges(context: context)
            return awarded
        } catch {
            context.rollback()
            wallet.refreshQuestProjection(context: context, manager: questManager)
            #if DEBUG
                OhanaLog.error("[OasisCritterEconomyService] special award failed: \(error.localizedDescription)", category: "Oasis")
            #endif
            return nil
        }
    }

    private static func saveCritterEconomyChanges(context: ModelContext) throws {
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            throw OasisRewardWriteError.persistenceFailed(saveResult.errorDescription ?? "Unknown save failure")
        }
    }

    @discardableResult
    static func awardSpecialCurrentHumanCoconuts(
        _ amount: Int,
        emoji: String,
        title: String,
        sourceModelName: String,
        sourceModelId: String,
        transactionKey: String,
        metadataJSON: String = "",
        context: ModelContext,
        postsRewardFeedback: Bool = true,
        occurredAt: Date = Date()
    ) -> Int? {
        awardSpecialCurrentHumanCoconuts(
            amount,
            emoji: emoji,
            title: title,
            sourceModelName: sourceModelName,
            sourceModelId: sourceModelId,
            transactionKey: transactionKey,
            metadataJSON: metadataJSON,
            context: context,
            postsRewardFeedback: postsRewardFeedback,
            activeHumanSelection: UserDefaultsActiveHumanSelection(),
            wallet: SwiftDataCoconutWalletManager(),
            questManager: QuestManager(),
            occurredAt: occurredAt
        )
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
        guard let human = currentHuman(context: context, activeHumanSelection: activeHumanSelection) else {
            return false
        }
        guard amount > 0 else { return true }
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
}
