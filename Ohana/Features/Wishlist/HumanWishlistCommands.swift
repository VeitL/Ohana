//
//  HumanWishlistCommands.swift
//  Ohana
//
//  Human wishlist write boundary and revision publishing.
//

import Foundation
import SwiftData

@MainActor
private func fetchHumanWishlistModelsOrLog<T: PersistentModel>(
    _ descriptor: FetchDescriptor<T>,
    context: ModelContext,
    operation: String
) -> [T] {
    do {
        return try context.fetch(descriptor)
    } catch {
        OhanaLog.warning(
            "HumanWishlistCommands failed to \(operation): \(error.localizedDescription)",
            category: "Care"
        )
        return []
    }
}

enum HumanWishlistCommandError: LocalizedError, Equatable {
    case emptyTitle
    case invalidCost
    case itemOwnershipMismatch
    case alreadyRedeemed
    case insufficientCoconuts(missing: Int)
    case persistenceFailed(String?)

    var errorDescription: String? {
        let l = L10n.current
        switch self {
        case .emptyTitle:
            return l.tr(zh: "心愿内容不能为空。", en: "Wish title cannot be empty.", de: "Der Wunsch darf nicht leer sein.")
        case .invalidCost:
            return l.tr(zh: "心愿兑换费用必须大于 0。", en: "Wish cost must be greater than 0.", de: "Wunschkosten müssen größer als 0 sein.")
        case .itemOwnershipMismatch:
            return l.tr(zh: "这个心愿不属于当前成员。", en: "This wish does not belong to the current member.", de: "Dieser Wunsch gehört nicht zum aktuellen Mitglied.")
        case .alreadyRedeemed:
            return l.tr(zh: "这个心愿已经兑换。", en: "This wish has already been redeemed.", de: "Dieser Wunsch wurde bereits eingelöst.")
        case let .insufficientCoconuts(missing):
            return l.tr(zh: "椰子余额不足，还差 \(missing) 个。", en: "Not enough coconuts. Need \(missing) more.", de: "Nicht genug Kokosnüsse. Es fehlen \(missing).")
        case let .persistenceFailed(reason):
            let detail = reason.map { "\n\($0)" } ?? ""
            return l.tr(
                zh: "心愿保存失败，请稍后重试。\(detail)",
                en: "Could not save the wish. Try again.\(detail)",
                de: "Der Wunsch konnte nicht gespeichert werden. Versuche es erneut.\(detail)"
            )
        }
    }
}

struct HumanWishlistCommandInput: Equatable {
    let title: String
    let cost: Int
    let createdAt: Date

    init(title: String, cost: Int, createdAt: Date = Date()) {
        self.title = title
        self.cost = cost
        self.createdAt = createdAt
    }
}

struct HumanWishlistCommandResult: Equatable {
    let humanID: UUID
    let itemID: UUID
    let coconutDelta: Int
    let ledgerEventID: UUID?
    let isRedeemed: Bool
}

struct HumanWishlistDeleteCommandResult: Equatable {
    let humanID: UUID
    let itemID: UUID
    let removedLedgerEventIDs: [UUID]
}

enum HumanWishlistCommandService {
    @discardableResult
    @MainActor
    static func createItem(
        input: HumanWishlistCommandInput,
        for human: Human,
        context: ModelContext
    ) throws -> HumanWishlistCommandResult {
        let title = input.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { throw HumanWishlistCommandError.emptyTitle }
        guard input.cost > 0 else { throw HumanWishlistCommandError.invalidCost }
        guard let write = DomainMemberFactWriteAuthorizer.authorizeHumanFact(
            human: human,
            occurredAt: input.createdAt,
            writeKind: .collaboration,
            source: .userCommand,
            context: context,
            logPrefix: "HumanWishlistCommandService"
        ) else {
            throw HumanWishlistCommandError.itemOwnershipMismatch
        }

        let item = DomainMemberFactWriter.createWishlistItem(
            plan: write,
            title: title,
            cost: input.cost,
            human: human,
            createdAt: input.createdAt,
            context: context
        )
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            throw HumanWishlistCommandError.persistenceFailed(saveResult.errorDescription)
        }
        return HumanWishlistCommandResult(
            humanID: human.id,
            itemID: item.id,
            coconutDelta: 0,
            ledgerEventID: nil,
            isRedeemed: false
        )
    }

    @discardableResult
    @MainActor
    static func redeemItem(
        _ item: WishlistItem,
        for human: Human,
        redeemedById: String?,
        context: ModelContext,
        questManager providedQuestManager: QuestManager? = nil,
        careLedger providedCareLedger: CareLedgerRecording? = nil,
        wallet providedWallet: CoconutWalletManaging? = nil
    ) throws -> HumanWishlistCommandResult {
        let questManager = providedQuestManager ?? QuestManager()
        let careLedger: CareLedgerRecording = providedCareLedger ?? CareLedgerService()
        let wallet: CoconutWalletManaging = providedWallet ?? SwiftDataCoconutWalletManager()
        let now = Date()
        guard let write = DomainMemberFactWriteAuthorizer.authorizeHumanFact(
            human: human,
            occurredAt: now,
            writeKind: .collaboration,
            source: .userCommand,
            context: context,
            logPrefix: "HumanWishlistCommandService"
        ) else {
            throw HumanWishlistCommandError.itemOwnershipMismatch
        }
        guard item.creatorId == human.id.uuidString else {
            throw HumanWishlistCommandError.itemOwnershipMismatch
        }
        guard !item.isRedeemed else { throw HumanWishlistCommandError.alreadyRedeemed }
        guard item.cost > 0 else { throw HumanWishlistCommandError.invalidCost }
        let humanBalance = CoconutWalletService.balance(for: human, context: context)
        guard humanBalance >= item.cost else {
            throw HumanWishlistCommandError.insufficientCoconuts(missing: item.cost - humanBalance)
        }

        DomainMemberFactWriter.redeemWishlistItem(
            plan: write,
            item: item,
            redeemedById: normalizedId(redeemedById),
            context: context
        )

        let ledger = DomainMemberFactEffectsDispatcher.map(plan: write, default: nil as CareLedgerEvent?) { _ in
            careLedger.record(
                occurredAt: now,
                actorKind: .human,
                actorId: item.redeemedById ?? human.id.uuidString,
                subjectKind: .human,
                subjectId: human.id.uuidString,
                eventKind: .coconut,
                actionType: "humanWishlistRedeem",
                amountValue: Double(item.cost),
                amountUnit: "coconut",
                note: item.title,
                source: .economy,
                sourceEventId: nil,
                sourceReminderId: nil,
                legacyModelName: "WishlistItem",
                legacyModelId: item.id.uuidString,
                coconutDelta: -item.cost,
                rewardLogId: nil,
                privacyFieldRaw: HumanPrivateField.wishlist.rawValue,
                metadataJSON: "{\"wishlistItemId\":\"\(item.id.uuidString)\"}",
                context: context,
                save: false
            )
        }
        guard let ledger else {
            throw HumanWishlistCommandError.itemOwnershipMismatch
        }
        do {
            let l = L10n.current
            var walletApplyError: Error?
            DomainMemberFactEffectsDispatcher.run(plan: write) { _ in
                do {
                    try wallet.apply(
                        deltas: [
                            .human(
                                human,
                                delta: -item.cost,
                                entryKind: .spend,
                                source: .shop,
                                title: l.tr(zh: "兑换「\(item.title)」", en: "Redeemed \"\(item.title)\"", de: "\"\(item.title)\" eingelöst"),
                                emoji: "🎁",
                                actorId: human.id.uuidString,
                                actorName: human.name,
                                subjectKind: .human,
                                subjectId: human.id.uuidString,
                                sourceModelName: "WishlistItem",
                                sourceModelId: item.id.uuidString,
                                careLedgerEventId: ledger.id.uuidString,
                                metadataJSON: "{\"wishlistItemId\":\"\(item.id.uuidString)\"}",
                                transactionKey: "wishlist:\(item.id.uuidString):redeem"
                            )
                        ],
                        context: context,
                        save: false,
                        postsRewardFeedback: true,
                        updatesProjection: true,
                        projectionManager: questManager
                    )
                } catch {
                    walletApplyError = error
                }
            }
            if let walletApplyError {
                throw walletApplyError
            }
            let saveResult = context.safeSaveResult(publishFailureEvent: true)
            guard saveResult.didSave else {
                throw HumanWishlistCommandError.persistenceFailed(saveResult.errorDescription)
            }
        } catch {
            context.rollback()
            wallet.refreshQuestProjection(context: context, manager: questManager)
            throw error
        }

        return HumanWishlistCommandResult(
            humanID: human.id,
            itemID: item.id,
            coconutDelta: -item.cost,
            ledgerEventID: ledger.id,
            isRedeemed: true
        )
    }

    @discardableResult
    @MainActor
    static func deleteItem(
        _ item: WishlistItem,
        for human: Human,
        context: ModelContext
    ) throws -> HumanWishlistDeleteCommandResult {
        guard let write = DomainMemberFactWriteAuthorizer.authorizeHumanFact(
            human: human,
            occurredAt: Date(),
            writeKind: .collaboration,
            source: .userCommand,
            context: context,
            logPrefix: "HumanWishlistCommandService"
        ) else {
            throw HumanWishlistCommandError.itemOwnershipMismatch
        }
        guard item.creatorId == human.id.uuidString else {
            throw HumanWishlistCommandError.itemOwnershipMismatch
        }
        let ledgerEvents = ledgerEvents(for: item, context: context)
        DomainMemberFactEffectsDispatcher.run(plan: write) { _ in
            for ledgerEvent in ledgerEvents {
                CloudSyncMutationRecorder.markDeleted(ledgerEvent, context: context)
                context.delete(ledgerEvent)
            }
        }
        let itemID = item.id
        DomainMemberFactWriter.deleteWishlistItem(plan: write, item: item, context: context)
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            throw HumanWishlistCommandError.persistenceFailed(saveResult.errorDescription)
        }
        return HumanWishlistDeleteCommandResult(
            humanID: human.id,
            itemID: itemID,
            removedLedgerEventIDs: ledgerEvents.map(\.id)
        )
    }

    private static func normalizedId(_ raw: String?) -> String? {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    @MainActor
    private static func ledgerEvents(
        for item: WishlistItem,
        context: ModelContext
    ) -> [CareLedgerEvent] {
        let idString = item.id.uuidString
        let modelName = "WishlistItem"
        let descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { event in
                event.legacyModelName == modelName && event.legacyModelId == idString
            }
        )
        return fetchHumanWishlistModelsOrLog(
            descriptor,
            context: context,
            operation: "fetch wishlist ledger events"
        )
    }
}

@MainActor
struct HumanWishlistCommandExecutor {
    let context: ModelContext
    let revisions: DomainRevisionPublishing
    let questManager: QuestManager
    let careLedger: CareLedgerRecording
    let wallet: CoconutWalletManaging

    init(context: ModelContext) {
        self.init(
            context: context,
            revisions: SharedDomainRevisionPublisher(),
            questManager: QuestManager(),
            careLedger: CareLedgerService(),
            wallet: SwiftDataCoconutWalletManager()
        )
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        self.init(
            context: context,
            revisions: SharedDomainRevisionPublisher(center: revisionCenter),
            questManager: QuestManager(),
            careLedger: CareLedgerService(),
            wallet: SwiftDataCoconutWalletManager()
        )
    }

    init(context: ModelContext, services: AppServices) {
        self.init(
            context: context,
            revisions: services.domainRevisions,
            questManager: services.questManager,
            careLedger: services.careLedger,
            wallet: services.coconutWallet
        )
    }

    init(
        context: ModelContext,
        revisions: DomainRevisionPublishing,
        questManager: QuestManager,
        careLedger: CareLedgerRecording,
        wallet: CoconutWalletManaging
    ) {
        self.context = context
        self.revisions = revisions
        self.questManager = questManager
        self.careLedger = careLedger
        self.wallet = wallet
    }

    @discardableResult
    func createItem(
        input: HumanWishlistCommandInput,
        for human: Human,
        note: String
    ) throws -> HumanWishlistCommandResult {
        let result = try HumanWishlistCommandService.createItem(input: input, for: human, context: context)
        revisions.publishHumanWishlistCreate(result, note: note)
        return result
    }

    @discardableResult
    func redeemItem(
        _ item: WishlistItem,
        for human: Human,
        redeemedById: String?,
        questManager: QuestManager? = nil,
        note: String
    ) throws -> HumanWishlistCommandResult {
        let result = try HumanWishlistCommandService.redeemItem(
            item,
            for: human,
            redeemedById: redeemedById,
            context: context,
            questManager: questManager,
            careLedger: careLedger,
            wallet: wallet
        )
        revisions.publishHumanWishlistRedeem(result, note: note)
        return result
    }

    @discardableResult
    func deleteItem(
        _ item: WishlistItem,
        for human: Human,
        note: String
    ) throws -> HumanWishlistDeleteCommandResult {
        let result = try HumanWishlistCommandService.deleteItem(item, for: human, context: context)
        revisions.publishHumanWishlistDelete(result, note: note)
        return result
    }
}
