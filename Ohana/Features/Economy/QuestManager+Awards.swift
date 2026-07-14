//
//  QuestManager+Awards.swift
//  Ohana
//

import Foundation
import SwiftData
import UIKit

private enum QuestAwardPersistenceError: LocalizedError {
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case let .saveFailed(message):
            String(
                localized: "quest.award.persistence.failed",
                defaultValue: "Unable to save quest reward changes: \(message)"
            )
        }
    }
}

private func saveQuestAwardChanges(context: ModelContext) throws {
    let saveResult = context.safeSaveResult(publishFailureEvent: true)
    guard saveResult.didSave else {
        context.rollback()
        throw QuestAwardPersistenceError.saveFailed(saveResult.errorDescription ?? "Unknown save failure")
    }
}

extension QuestManager {
    // MARK: - 核心分发方法（新版，接受 OhanaActionType）
    /// - Parameters:
    ///   - type: OhanaActionType，携带奖励规则
    ///   - pet: 关联宠物（可空）
    ///   - context: ModelContext，用于 fetch Human 并 save
    @discardableResult
    func awardAction(
        type: OhanaActionType,
        pet: Pet?,
        context: ModelContext,
        quality: QualityBonus = .none,
        date: Date = Date(),
        executorId: String? = nil,
        careObjectKey: UUID? = nil
    ) -> (humanGot: Int, petGot: Int) {
        if let pet, !EconomyWalletWritePolicy.canWrite(pet) {
            lastEconomyRewardResult = .empty
            return (0, 0)
        }

        // ── 1. 人类账户（从 context fetch，安全降级）
        let human = EconomyRewardOwnerResolver.rewardHuman(
            executorId: executorId,
            activeHumanSelection: activeHumanSelection,
            context: context,
            logPrefix: "QuestManager"
        )
        if EconomyRewardOwnerResolver.hasExplicitExecutor(executorId), human == nil {
            lastEconomyRewardResult = .empty
            return (0, 0)
        }
        let consumesBoost = isDoubleRewardBoostActive()
        let cooldownSubjectId = careObjectKey ?? pet?.id
        let isCoolingDown = isOnCooldown(petId: cooldownSubjectId, type: type)
        let budgetKeys = economyBudgetKeys(for: human, context: context)
        let objectKeys = pet != nil ? careObjectKeys(for: pet) : careObjectKeys(forPlantId: careObjectKey)
        let result = CoconutEconomyPolicyV2.reward(
            for: type,
            quality: quality,
            isOnCooldown: isCoolingDown,
            userKey: budgetKeys.household,
            memberKey: budgetKeys.member,
            careObjectKeys: objectKeys,
            careObjectCount: CoconutEconomyPolicyV2.careObjectCount(context: context),
            hasHumanAccount: human != nil,
            hasPetAccount: pet != nil,
            date: date,
            forcedLuck: consumesBoost ? .golden : nil,
            context: context
        )
        lastEconomyRewardResult = result

        let finalHuman = result.humanCoconuts
        let finalPet = result.petCoconuts
        // ── 2. 钱包流水（拆分：宠物和人类各生成独立条目）
        let l = L10n.current
        let logEmoji = result.luck == .golden ? "🎁" : type.emoji
        var baseTitle = type.title(pet: pet, l: l)
        if let badge = quality.badgeLabel(l: l) {
            baseTitle += " · \(badge)"
        }
        if let luckTitle = Self.economyLuckTitle(result.luck, l: l) {
            baseTitle += " · \(luckTitle)"
        }

        var walletDeltas: [CoconutWalletDelta] = []
        if let p = pet, finalPet > 0 {
            walletDeltas.append(.pet(
                p,
                delta: finalPet,
                entryKind: .reward,
                source: .careEvent,
                title: baseTitle,
                emoji: logEmoji,
                actorId: p.id.uuidString,
                actorName: p.name,
                subjectKind: .pet,
                subjectId: p.id.uuidString,
                metadataJSON: result.metadataJSON
            ))
        }
        if let h = human, finalHuman > 0 {
            walletDeltas.append(.human(
                h,
                delta: finalHuman,
                entryKind: .reward,
                source: .careEvent,
                title: baseTitle,
                emoji: "🥥",
                actorId: h.id.uuidString,
                actorName: h.name,
                subjectKind: .human,
                subjectId: h.id.uuidString,
                metadataJSON: result.metadataJSON
            ))
        }

        // ── 3. 持久化（同一个 ModelContext 事务）
        do {
            try wallet.apply(
                deltas: walletDeltas,
                context: context,
                save: false,
                postsRewardFeedback: false,
                updatesProjection: true,
                projectionManager: self
            )
            EconomyDailyBudgetStore.commit(
                result,
                householdKey: budgetKeys.household,
                memberKey: budgetKeys.member,
                careObjectKeys: objectKeys,
                date: date,
                context: context,
                save: false,
                writeDefaults: false
            )
            try saveQuestAwardChanges(context: context)
            EconomyDailyBudgetStore.commit(
                result,
                householdKey: budgetKeys.household,
                memberKey: budgetKeys.member,
                careObjectKeys: objectKeys,
                date: date,
                context: nil,
                save: false
            )
            if consumesBoost {
                clearDoubleRewardBoost()
            }
            postEconomyFeedback(result, type: type, title: baseTitle, actorId: pet?.id.uuidString ?? human?.id.uuidString, actorName: pet?.name ?? human?.name)
            if case .walk = type, let humanId = human?.id.uuidString {
                recordWalkRewardToday(finalHuman, humanId: humanId)
            }
            // 记录冷却时间戳（持久化成功后才记录；冷却内补记不延长窗口）
            if !isCoolingDown {
                recordCooldown(petId: cooldownSubjectId, type: type)
            }
            // TASK C: 检查 Streak 里程碑奖励
            if let pet { streakRewards.checkAndAward(pet: pet, questManager: self, context: context) }
        } catch {
            context.rollback()
            lastEconomyRewardResult = .empty
            wallet.refreshQuestProjection(context: context, manager: self)
            #if DEBUG
                OhanaLog.error("[QuestManager] SwiftData save failed; rolled back: \(error.localizedDescription)", category: "Economy")
            #endif
            return (0, 0)
        }
        return (finalHuman, finalPet)
    }

    func human(withId humanId: String?, context: ModelContext) -> Human? {
        EconomyRewardOwnerResolver.explicitHuman(id: humanId, context: context, logPrefix: "QuestManager")
    }

    /// 多宠共同照护奖励：人类奖励只发一次，每只在世目标宠物各自获得成长椰子。
    @MainActor
    @discardableResult
    func awardSharedCareAction(
        type: OhanaActionType,
        pets: [Pet],
        context: ModelContext,
        quality: QualityBonus = .none,
        title: String? = nil,
        executorId: String? = nil,
        date: Date = Date(),
        idempotencyKey: String? = nil
    ) -> (humanGot: Int, petGot: Int) {
        let livePets = pets.filter { EconomyWalletWritePolicy.canWrite($0) }
        guard !livePets.isEmpty else { return (0, 0) }

        if let replay = replaySharedCareReward(
            idempotencyKey: idempotencyKey,
            type: type,
            pets: livePets,
            title: title,
            executorId: executorId,
            date: date,
            context: context
        ) {
            return replay
        }

        let human = EconomyRewardOwnerResolver.rewardHuman(
            executorId: executorId,
            activeHumanSelection: activeHumanSelection,
            context: context,
            logPrefix: "QuestManager"
        )
        if EconomyRewardOwnerResolver.hasExplicitExecutor(executorId), human == nil {
            lastEconomyRewardResult = .empty
            return (0, 0)
        }
        let consumesBoost = isDoubleRewardBoostActive()
        let plan = makeSharedCareAwardPlan(
            type: type,
            livePets: livePets,
            human: human,
            context: context,
            quality: quality,
            title: title,
            date: date,
            idempotencyKey: idempotencyKey,
            consumesBoost: consumesBoost
        )
        lastEconomyRewardResult = plan.result

        do {
            try persistSharedCareAward(
                plan,
                context: context,
                date: date,
                idempotencyKey: idempotencyKey
            )
            applySharedCareRuntimeEffects(
                plan.result,
                type: type,
                pets: livePets,
                title: plan.sharedTitle,
                executorId: executorId,
                date: date,
                consumesBoost: consumesBoost,
                context: context
            )
        } catch {
            context.rollback()
            lastEconomyRewardResult = .empty
            wallet.refreshQuestProjection(context: context, manager: self)
            #if DEBUG
                OhanaLog.error("[QuestManager] shared care save failed: \(error.localizedDescription)", category: "Economy")
            #endif
            return (0, 0)
        }

        return (plan.humanTotal, plan.petTotal)
    }

    private struct SharedCareAwardPlan {
        let result: EconomyRewardResult
        let budgetKeys: (household: String, member: String)
        let objectKeys: [String]
        let walletDeltas: [CoconutWalletDelta]
        let sharedTitle: String
        let humanTotal: Int
        let petTotal: Int
    }

    private func replaySharedCareReward(
        idempotencyKey: String?,
        type: OhanaActionType,
        pets: [Pet],
        title: String?,
        executorId: String?,
        date: Date,
        context: ModelContext
    ) -> (humanGot: Int, petGot: Int)? {
        guard let idempotencyKey,
              let existing = existingSharedCareReward(
                  idempotencyKey: idempotencyKey,
                  context: context
              ) else { return nil }
        let restoredResult = Self.rewardResult(from: existing.metadataJSON)
        lastEconomyRewardResult = restoredResult
        wallet.refreshQuestProjection(context: context, manager: self)
        if let restoredResult {
            applySharedCareRuntimeEffects(
                restoredResult,
                type: type,
                pets: pets,
                title: title,
                executorId: executorId,
                date: date,
                consumesBoost: Self.boolValue(
                    named: "consumesBoost",
                    metadataJSON: existing.metadataJSON
                ),
                context: context
            )
        }
        return (
            existing.entries.filter { $0.ownerKind == .human }.reduce(0) { $0 + max(0, $1.delta) },
            existing.entries.filter { $0.ownerKind == .pet }.reduce(0) { $0 + max(0, $1.delta) }
        )
    }

    private func makeSharedCareAwardPlan(
        type: OhanaActionType,
        livePets: [Pet],
        human: Human?,
        context: ModelContext,
        quality: QualityBonus,
        title: String?,
        date: Date,
        idempotencyKey: String?,
        consumesBoost: Bool
    ) -> SharedCareAwardPlan {
        let budgetKeys = economyBudgetKeys(for: human, context: context)
        let objectKeys = careObjectKeys(for: livePets)
        let result = CoconutEconomyPolicyV2.sharedReward(
            for: type,
            targetCount: livePets.count,
            quality: quality,
            isOnCooldown: livePets.allSatisfy { isOnCooldown(petId: $0.id, type: type) },
            userKey: budgetKeys.household,
            memberKey: budgetKeys.member,
            careObjectKeys: objectKeys,
            careObjectCount: CoconutEconomyPolicyV2.careObjectCount(context: context),
            hasHumanAccount: human != nil,
            date: date,
            forcedLuck: consumesBoost ? .golden : nil,
            context: context
        )
        let petAwards = Self.distribute(result.petCoconuts, count: livePets.count)
        let humanTotal = human == nil ? 0 : result.humanCoconuts
        let l = L10n.current
        var sharedTitle = title ?? Self.sharedCareTitle(
            petNames: Self.sharedCarePetNames(livePets, l: l),
            l: l
        )
        if let luckTitle = Self.economyLuckTitle(result.luck, l: l) {
            sharedTitle += " · \(luckTitle)"
        }
        let walletMetadata = Self.sharedCareRewardMetadata(
            result.metadataJSON,
            idempotencyKey: idempotencyKey,
            consumesBoost: consumesBoost
        )
        return SharedCareAwardPlan(
            result: result,
            budgetKeys: budgetKeys,
            objectKeys: objectKeys,
            walletDeltas: Self.sharedCareWalletDeltas(
                livePets: livePets,
                petAwards: petAwards,
                human: human,
                humanTotal: humanTotal,
                humanTitle: Self.sharedCareHumanTitle(isGolden: result.luck == .golden, l: l),
                sharedTitle: sharedTitle,
                walletMetadata: walletMetadata,
                idempotencyKey: idempotencyKey,
                date: date,
                logEmoji: result.luck == .golden ? "🎁" : type.emoji
            ),
            sharedTitle: sharedTitle,
            humanTotal: humanTotal,
            petTotal: petAwards.reduce(0, +)
        )
    }

    private static func sharedCareWalletDeltas(
        livePets: [Pet],
        petAwards: [Int],
        human: Human?,
        humanTotal: Int,
        humanTitle: String,
        sharedTitle: String,
        walletMetadata: String,
        idempotencyKey: String?,
        date: Date,
        logEmoji: String
    ) -> [CoconutWalletDelta] {
        let sourceModelName = idempotencyKey == nil ? "" : "SharedCareFinalization"
        let sourceModelId = idempotencyKey ?? ""
        var deltas = livePets.enumerated().compactMap { index, pet -> CoconutWalletDelta? in
            guard petAwards[index] > 0 else { return nil }
            return .pet(
                pet,
                delta: petAwards[index],
                entryKind: .reward,
                source: .careEvent,
                title: sharedTitle,
                emoji: logEmoji,
                actorId: pet.id.uuidString,
                actorName: pet.name,
                subjectKind: .pet,
                subjectId: pet.id.uuidString,
                sourceModelName: sourceModelName,
                sourceModelId: sourceModelId,
                metadataJSON: walletMetadata,
                occurredAt: date,
                transactionKey: idempotencyKey.map { "\($0):pet:\(pet.id.uuidString)" }
            )
        }
        if let human, humanTotal > 0 {
            deltas.append(.human(
                human,
                delta: humanTotal,
                entryKind: .reward,
                source: .careEvent,
                title: humanTitle,
                emoji: "🥥",
                actorId: human.id.uuidString,
                actorName: human.name,
                subjectKind: .human,
                subjectId: human.id.uuidString,
                sourceModelName: sourceModelName,
                sourceModelId: sourceModelId,
                metadataJSON: walletMetadata,
                occurredAt: date,
                transactionKey: idempotencyKey.map { "\($0):human:\(human.id.uuidString)" }
            ))
        }
        if let idempotencyKey, deltas.isEmpty {
            deltas.append(.island(
                delta: 0,
                entryKind: .legacyHistory,
                source: .careEvent,
                title: sharedTitle,
                emoji: "🧾",
                subjectKind: .household,
                sourceModelName: sourceModelName,
                sourceModelId: sourceModelId,
                metadataJSON: walletMetadata,
                occurredAt: date,
                transactionKey: "\(idempotencyKey):marker",
                affectsBalance: false
            ))
        }
        return deltas
    }

    private func persistSharedCareAward(
        _ plan: SharedCareAwardPlan,
        context: ModelContext,
        date: Date,
        idempotencyKey: String?
    ) throws {
        try wallet.apply(
            deltas: plan.walletDeltas,
            context: context,
            save: false,
            postsRewardFeedback: false,
            updatesProjection: true,
            projectionManager: self
        )
        EconomyDailyBudgetStore.commit(
            plan.result,
            householdKey: plan.budgetKeys.household,
            memberKey: plan.budgetKeys.member,
            careObjectKeys: plan.objectKeys,
            date: date,
            context: context,
            save: false,
            writeDefaults: false
        )
        try saveQuestAwardChanges(context: context)
        if idempotencyKey == nil {
            EconomyDailyBudgetStore.commit(
                plan.result,
                householdKey: plan.budgetKeys.household,
                memberKey: plan.budgetKeys.member,
                careObjectKeys: plan.objectKeys,
                date: date,
                context: nil,
                save: false
            )
        }
    }

    private struct ExistingSharedCareReward {
        let entries: [CoconutLedgerEntry]
        let metadataJSON: String
    }

    private func existingSharedCareReward(
        idempotencyKey: String,
        context: ModelContext
    ) -> ExistingSharedCareReward? {
        let sourceModelName = "SharedCareFinalization"
        var descriptor = FetchDescriptor<CoconutLedgerEntry>(
            predicate: #Predicate<CoconutLedgerEntry> {
                $0.sourceModelName == sourceModelName && $0.sourceModelId == idempotencyKey
            },
            sortBy: [SortDescriptor(\.occurredAt)]
        )
        descriptor.fetchLimit = 64
        guard let entries = try? context.fetch(descriptor), !entries.isEmpty else { return nil }
        return ExistingSharedCareReward(
            entries: entries,
            metadataJSON: entries.first?.metadataJSON ?? ""
        )
    }

    private static func sharedCareRewardMetadata(
        _ metadataJSON: String,
        idempotencyKey: String?,
        consumesBoost: Bool
    ) -> String {
        guard let idempotencyKey,
              let data = metadataJSON.data(using: .utf8),
              var object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return metadataJSON
        }
        object["sharedCareIdempotencyKey"] = idempotencyKey
        object["consumesBoost"] = consumesBoost
        guard let encoded = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let json = String(data: encoded, encoding: .utf8) else { return metadataJSON }
        return json
    }

    private static func rewardResult(from metadataJSON: String) -> EconomyRewardResult? {
        guard let data = metadataJSON.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        func int(_ key: String) -> Int { (object[key] as? NSNumber)?.intValue ?? 0 }
        func double(_ key: String) -> Double { (object[key] as? NSNumber)?.doubleValue ?? 0 }
        func bool(_ key: String) -> Bool { (object[key] as? NSNumber)?.boolValue ?? false }
        func string(_ key: String) -> String { object[key] as? String ?? "" }
        let stage = EconomyBudgetStage(rawValue: string("budgetStage")) ?? .normal
        let luck = EconomyLuckTier(rawValue: string("luck")) ?? .none
        return EconomyRewardResult(
            growthXP: int("growthXP"),
            humanCoconuts: int("humanCoconuts"),
            petCoconuts: int("petCoconuts"),
            bonusCoconuts: int("coconutBonus"),
            luckyCoconuts: int("luckyCoconuts"),
            budgetMultiplier: double("budgetMultiplier"),
            budgetStage: stage,
            reason: string("reason"),
            actionKey: string("actionKey"),
            isOnCooldown: bool("cooldown"),
            baseGrowthXP: int("growthXP"),
            baseCoconuts: int("coconutBase"),
            luck: luck
        )
    }

    private static func boolValue(named key: String, metadataJSON: String) -> Bool {
        guard let data = metadataJSON.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }
        return (object[key] as? NSNumber)?.boolValue ?? false
    }

    private func applySharedCareRuntimeEffects(
        _ result: EconomyRewardResult,
        type: OhanaActionType,
        pets: [Pet],
        title: String?,
        executorId: String?,
        date: Date,
        consumesBoost: Bool,
        context: ModelContext
    ) {
        if consumesBoost {
            clearDoubleRewardBoost()
        }
        let human = EconomyRewardOwnerResolver.rewardHuman(
            executorId: executorId,
            activeHumanSelection: activeHumanSelection,
            context: context,
            logPrefix: "QuestManager"
        )
        let resolvedTitle = title ?? Self.sharedCareTitle(
            petNames: Self.sharedCarePetNames(pets, l: .current),
            l: .current
        )
        postEconomyFeedback(
            result,
            type: type,
            title: resolvedTitle,
            actorId: human?.id.uuidString ?? pets.first?.id.uuidString,
            actorName: human?.name ?? pets.first?.name
        )
        for pet in pets {
            recordCooldown(petId: pet.id, type: type, occurredAt: date)
            streakRewards.checkAndAward(pet: pet, questManager: self, context: context)
        }
    }

    private static func economyLuckTitle(_ luck: EconomyLuckTier, l: L10n) -> String? {
        switch luck {
        case .none:
            nil
        case .small:
            l.tr(zh: "小幸运", en: "Lucky boost", de: "Kleiner Glücksbonus")
        case .golden:
            l.tr(zh: "金色幸运", en: "Golden luck", de: "Goldglück")
        }
    }

    private static func sharedCarePetNames(_ pets: [Pet], l: L10n) -> String {
        let displayedNames = pets.prefix(3).map(\.name)
        let head = displayedNames.joined(separator: l.isChinese ? "、" : ", ")
        let remaining = pets.count - displayedNames.count
        guard remaining > 0 else { return head }
        return l.tr(
            zh: "\(head) 等\(pets.count)只",
            en: "\(head) + \(remaining) more",
            de: "\(head) + \(remaining) weitere"
        )
    }

    private static func sharedCareTitle(petNames: String, l: L10n) -> String {
        l.tr(zh: "共同照护 · \(petNames)", en: "Shared care · \(petNames)", de: "Gemeinsame Pflege · \(petNames)")
    }

    private static func sharedCareHumanTitle(isGolden: Bool, l: L10n) -> String {
        if isGolden {
            return l.tr(
                zh: "金色幸运共同照护奖励",
                en: "Golden luck shared care reward",
                de: "Goldglück-Bonus für gemeinsame Pflege"
            )
        }
        return l.tr(zh: "共同照护奖励", en: "Shared care reward", de: "Bonus für gemeinsame Pflege")
    }
}
