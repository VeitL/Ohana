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
    func addCoconuts(_ amount: Int, emoji: String = "🥥", title: String = "打卡奖励", reason: String? = nil,
                     actorId: String? = nil, actorName: String? = nil) {
        let finalTitle = reason ?? title
        let context = ModelContext(SharedModelContainer.make())
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
            try wallet.applyActorDelta(
                amount: amount,
                emoji: emoji,
                title: title,
                actorId: actorId,
                actorName: actorName,
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
        let delta = try specialCoconutDelta(
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
        )
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
        let context = ModelContext(SharedModelContainer.make())
        do {
            try wallet.applyActorDelta(
                amount: amount,
                emoji: emoji,
                title: title,
                actorId: actorId,
                actorName: actorName,
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
    ) throws -> CoconutWalletDelta {
        guard let actorId, actorId != "system", let uuid = UUID(uuidString: actorId) else {
            return .system(
                delta: amount,
                entryKind: .reward,
                source: source,
                title: title,
                emoji: emoji,
                actorId: actorId ?? "system",
                actorName: actorName ?? "System",
                sourceModelName: sourceModelName,
                sourceModelId: sourceModelId,
                metadataJSON: metadataJSON,
                occurredAt: occurredAt,
                transactionKey: transactionKey
            )
        }

        if let human = try fetchHuman(id: uuid, context: context) {
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
        return .system(
            delta: amount,
            entryKind: .reward,
            source: source,
            title: title,
            emoji: emoji,
            actorId: actorId,
            actorName: actorName,
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

        let islandDelta = (petGet > 0 && pet != nil ? petGet : 0)
            + (humanGet > 0 && human != nil ? humanGet : 0)
        let fallback = (islandDelta == 0) ? amount : 0 // potty/general 无实体时保底给全岛

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
        let context = ModelContext(SharedModelContainer.make())
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
                    actorId: aId,
                    actorName: aName,
                    entryKind: .reward,
                    source: .service,
                    context: context,
                    save: false,
                    postsRewardFeedback: true,
                    projectionManager: self
                )
            }
            try context.save()
        } catch {
            context.rollback()
            wallet.refreshQuestProjection(context: context, manager: self)
            #if DEBUG
                OhanaLog.error("[QuestManager] legacy award wallet write failed: \(error.localizedDescription)", category: "Economy")
            #endif
        }
    }
}
