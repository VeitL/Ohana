//
//  QuestManager+LegacyWallet.swift
//  Ohana
//

import Foundation
import SwiftData
import UIKit

extension QuestManager {
    // MARK: - 旧版兼容方法（addCoconuts / awardAction with allHumans）
    // 这些方法仍保留，内部调用不再触发个人账户分润，仅用于无上下文场景（如首日登录奖励）

    /// 仅更新全岛总库（用于无实体关联的全局奖励）
    func addCoconuts(
        _ amount: Int,
        emoji: String = "🥥",
        title: String = "打卡奖励",
        reason: String? = nil,
        actorId: String? = nil,
        actorName: String? = nil
    ) {
        let finalTitle = reason ?? title
        guard let container = try? SharedModelContainer.make() else { return }
        let context = ModelContext(container)
        addCoconuts(
            amount,
            emoji: emoji,
            title: finalTitle,
            actorId: actorId,
            actorName: actorName,
            context: context,
            save: true
        )
    }

    @discardableResult
    func addCoconuts(
        _ amount: Int,
        emoji: String = "🥥",
        title: String = "打卡奖励",
        actorId: String? = nil,
        actorName: String? = nil,
        context: ModelContext,
        save: Bool
    ) -> Int {
        lastEconomyRewardResult = nil
        guard amount != 0 else { return 0 }
        do {
            guard let actor = try legacyWalletActor(actorId: actorId, actorName: actorName, context: context) else {
                return 0
            }
            try wallet.applyActorDelta(
                amount: amount,
                emoji: emoji,
                title: title,
                actorId: actor.id,
                actorName: actor.name,
                entryKind: amount > 0 ? .reward : .spend,
                source: .service,
                context: context,
                save: save,
                postsRewardFeedback: true,
                projectionManager: self
            )
            return amount
        } catch {
            context.rollback()
            wallet.refreshQuestProjection(context: context, manager: self)
            #if DEBUG
                OhanaLog.error("[QuestManager] coconut wallet add failed: \(error.localizedDescription)", category: "Economy")
            #endif
            return 0
        }
    }

    /// Stages a deterministic, non-budgeted grant for one concrete business fact.
    /// Use this for special or compatibility rewards only; repeatable care rewards should use V2 awardAction.
    @discardableResult
    func stageSpecialCoconutReward(
        amount: Int,
        emoji: String = "🥥",
        title: String,
        actorId: String? = nil,
        actorName: String? = nil,
        source: CoconutWalletSource = .service,
        sourceModelName: String,
        sourceModelId: String,
        metadataJSON: String = "",
        transactionKey: String,
        context: ModelContext,
        occurredAt: Date = Date(),
        postsRewardFeedback: Bool = true
    ) throws -> Int {
        lastEconomyRewardResult = nil
        guard amount > 0 else { return 0 }
        guard let delta = try specialCoconutDelta(
            amount: amount,
            emoji: emoji,
            title: title,
            actorId: actorId,
            actorName: actorName,
            source: source,
            sourceModelName: sourceModelName,
            sourceModelId: sourceModelId,
            metadataJSON: metadataJSON,
            transactionKey: transactionKey,
            context: context,
            occurredAt: occurredAt
        ) else { return 0 }
        let entries = try wallet.apply(
            deltas: [delta],
            context: context,
            save: false,
            postsRewardFeedback: postsRewardFeedback,
            updatesProjection: true,
            projectionManager: self
        )
        return entries
            .filter(\.affectsBalance)
            .reduce(0) { $0 + $1.delta }
    }

    /// 记录确定金额的椰子变动，不触发暴击、双倍券或质量加成。用于商店消费、兑换退款等经济账。
    func recordCoconutDelta(
        _ amount: Int,
        emoji: String = "🥥",
        title: String,
        actorId: String? = nil,
        actorName: String? = nil,
        postsRewardFeedback: Bool = true
    ) {
        guard amount != 0 else { return }
        guard let container = try? SharedModelContainer.make() else { return }
        let context = ModelContext(container)
        do {
            guard let actor = try legacyWalletActor(actorId: actorId, actorName: actorName, context: context) else {
                return
            }
            try wallet.applyActorDelta(
                amount: amount,
                emoji: emoji,
                title: title,
                actorId: actor.id,
                actorName: actor.name,
                entryKind: amount > 0 ? .refund : .spend,
                source: .service,
                context: context,
                save: true,
                postsRewardFeedback: postsRewardFeedback,
                projectionManager: self
            )
        } catch {
            context.rollback()
            wallet.refreshQuestProjection(context: context, manager: self)
            #if DEBUG
                OhanaLog.error("[QuestManager] coconut wallet delta failed: \(error.localizedDescription)", category: "Economy")
            #endif
        }
    }

    private func specialCoconutDelta(
        amount: Int,
        emoji: String,
        title: String,
        actorId: String?,
        actorName: String?,
        source: CoconutWalletSource,
        sourceModelName: String,
        sourceModelId: String,
        metadataJSON: String,
        transactionKey: String,
        context: ModelContext,
        occurredAt: Date
    ) throws -> CoconutWalletDelta? {
        guard let actorId, actorId != "system", let uuid = UUID(uuidString: actorId) else {
            return activeHumanSpecialCoconutDelta(
                amount: amount,
                emoji: emoji,
                title: title,
                source: source,
                sourceModelName: sourceModelName,
                sourceModelId: sourceModelId,
                metadataJSON: metadataJSON,
                transactionKey: transactionKey,
                context: context,
                occurredAt: occurredAt
            )
        }

        if let human = try fetchHuman(id: uuid, context: context) {
            guard EconomyWalletWritePolicy.canWrite(human) else { return nil }
            return .human(
                human,
                delta: amount,
                entryKind: .reward,
                source: source,
                title: title,
                emoji: emoji,
                actorId: actorId,
                actorName: actorName ?? human.name,
                sourceModelName: sourceModelName,
                sourceModelId: sourceModelId,
                metadataJSON: metadataJSON,
                occurredAt: occurredAt,
                transactionKey: transactionKey
            )
        }
        if let pet = try fetchPet(id: uuid, context: context) {
            guard EconomyWalletWritePolicy.canWrite(pet) else { return nil }
            return .pet(
                pet,
                delta: amount,
                entryKind: .reward,
                source: source,
                title: title,
                emoji: emoji,
                actorId: actorId,
                actorName: actorName ?? pet.name,
                sourceModelName: sourceModelName,
                sourceModelId: sourceModelId,
                metadataJSON: metadataJSON,
                occurredAt: occurredAt,
                transactionKey: transactionKey
            )
        }
        return activeHumanSpecialCoconutDelta(
            amount: amount,
            emoji: emoji,
            title: title,
            source: source,
            sourceModelName: sourceModelName,
            sourceModelId: sourceModelId,
            metadataJSON: metadataJSON,
            transactionKey: transactionKey,
            context: context,
            occurredAt: occurredAt
        )
    }

    private func activeHumanSpecialCoconutDelta(
        amount: Int,
        emoji: String,
        title: String,
        source: CoconutWalletSource,
        sourceModelName: String,
        sourceModelId: String,
        metadataJSON: String,
        transactionKey: String,
        context: ModelContext,
        occurredAt: Date
    ) -> CoconutWalletDelta? {
        guard let human = EconomyRewardOwnerResolver.activeHuman(
            selection: activeHumanSelection,
            context: context,
            logPrefix: "QuestManager"
        ) else {
            return nil
        }
        return .human(
            human,
            delta: amount,
            entryKind: .reward,
            source: source,
            title: title,
            emoji: emoji,
            actorId: human.id.uuidString,
            actorName: human.name,
            sourceModelName: sourceModelName,
            sourceModelId: sourceModelId,
            metadataJSON: metadataJSON,
            occurredAt: occurredAt,
            transactionKey: transactionKey
        )
    }

    private func fetchHuman(id: UUID, context: ModelContext) throws -> Human? {
        var descriptor = FetchDescriptor<Human>(
            predicate: #Predicate<Human> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func fetchPet(id: UUID, context: ModelContext) throws -> Pet? {
        var descriptor = FetchDescriptor<Pet>(
            predicate: #Predicate<Pet> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// 旧版签名兼容；内部映射到新规则。
    func awardAction(
        type: ActionType,
        amount: Int,
        pet: Pet? = nil,
        humanId: String? = nil,
        allHumans: [Human] = []
    ) {
        let human: Human? = humanId.flatMap { hid in allHumans.first { $0.id.uuidString == hid } }
        let aId = human?.id.uuidString ?? pet?.id.uuidString
        let aName = human?.name ?? pet?.name

        // 映射旧规则：全岛总库只加「实际到账」部分
        let humanGet: Int
        let petGet: Int
        switch type {
        case .walk, .feed, .water:
            humanGet = amount
            petGet = amount
        case .litter:
            humanGet = amount
            petGet = 0
        case .potty, .general:
            humanGet = 0
            petGet = 0
        }
        guard let container = try? SharedModelContainer.make() else { return }
        let context = ModelContext(container)
        let fallbackHuman = (human == nil && pet == nil)
            ? EconomyRewardOwnerResolver.activeHuman(
                selection: activeHumanSelection,
                context: context,
                logPrefix: "QuestManager"
            )
            : nil

        let islandDelta = (petGet > 0 && pet != nil ? petGet : 0)
            + (humanGet > 0 && human != nil ? humanGet : 0)
        let fallback = (islandDelta == 0 && fallbackHuman != nil) ? amount : 0

        let titleStr: String
        let emojiStr = type.emoji
        switch type {
        case .walk: titleStr = "\(pet?.name ?? "") 遛狗奖励"
        case .feed: titleStr = "\(pet?.name ?? "") 喂食奖励"
        case .litter: titleStr = "\(pet?.name ?? "") 铲屎奖励"
        case .potty: titleStr = "\(pet?.name ?? "") 便便打卡"
        case .water: titleStr = "\(pet?.name ?? "") 喂水奖励"
        case .general: titleStr = "打卡奖励"
        }
        do {
            if let pet, petGet > 0 {
                try wallet.applyActorDelta(
                    amount: petGet,
                    emoji: emojiStr,
                    title: titleStr,
                    actorId: pet.id.uuidString,
                    actorName: pet.name,
                    entryKind: .reward,
                    source: .service,
                    context: context,
                    save: false,
                    postsRewardFeedback: true,
                    projectionManager: self
                )
            }
            if let human, humanGet > 0 {
                try wallet.applyActorDelta(
                    amount: humanGet,
                    emoji: emojiStr,
                    title: titleStr,
                    actorId: human.id.uuidString,
                    actorName: human.name,
                    entryKind: .reward,
                    source: .service,
                    context: context,
                    save: false,
                    postsRewardFeedback: true,
                    projectionManager: self
                )
            }
            if fallback != 0 {
                try wallet.applyActorDelta(
                    amount: fallback,
                    emoji: emojiStr,
                    title: titleStr,
                    actorId: fallbackHuman?.id.uuidString ?? aId,
                    actorName: fallbackHuman?.name ?? aName,
                    entryKind: .reward,
                    source: .service,
                    context: context,
                    save: false,
                    postsRewardFeedback: true,
                    projectionManager: self
                )
            }
            let saveResult = context.safeSaveResult(publishFailureEvent: true)
            guard saveResult.didSave else {
                context.rollback()
                throw QuestLegacyWalletPersistenceError.saveFailed(saveResult.errorDescription ?? "Unknown save failure")
            }
        } catch {
            context.rollback()
            wallet.refreshQuestProjection(context: context, manager: self)
            #if DEBUG
                OhanaLog.error("[QuestManager] legacy award wallet write failed: \(error.localizedDescription)", category: "Economy")
            #endif
        }
    }

    private enum QuestLegacyWalletPersistenceError: LocalizedError {
        case saveFailed(String)

        var errorDescription: String? {
            switch self {
            case let .saveFailed(message):
                String(
                    localized: "quest.legacy.wallet.persistence.failed",
                    defaultValue: "Unable to save legacy wallet reward changes: \(message)"
                )
            }
        }
    }

    private func legacyWalletActor(
        actorId: String?,
        actorName: String?,
        context: ModelContext
    ) throws -> (id: String, name: String)? {
        guard let actorId, actorId != "system", let uuid = UUID(uuidString: actorId) else {
            guard let human = EconomyRewardOwnerResolver.activeHuman(
                selection: activeHumanSelection,
                context: context,
                logPrefix: "QuestManager"
            ) else {
                return nil
            }
            return (human.id.uuidString, human.name)
        }
        if let human = try fetchHuman(id: uuid, context: context), EconomyWalletWritePolicy.canWrite(human) {
            return (human.id.uuidString, actorName ?? human.name)
        }
        if let pet = try fetchPet(id: uuid, context: context), EconomyWalletWritePolicy.canWrite(pet) {
            return (pet.id.uuidString, actorName ?? pet.name)
        }
        return nil
    }
}
