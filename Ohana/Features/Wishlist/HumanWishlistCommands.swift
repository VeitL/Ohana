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

    var errorDescription: String? {
        switch self {
        case .emptyTitle:
            "心愿内容不能为空。"
        case .invalidCost:
            "心愿兑换费用必须大于 0。"
        case .itemOwnershipMismatch:
            "这个心愿不属于当前成员。"
        case .alreadyRedeemed:
            "这个心愿已经兑换。"
        case let .insufficientCoconuts(missing):
            "椰子余额不足，还差 \(missing) 个。"
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

        let item = WishlistItem(title: title, cost: input.cost, creatorId: human.id.uuidString)
        item.createdAt = input.createdAt
        context.insert(item)
        context.safeSave()
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
        guard item.creatorId == human.id.uuidString else {
            throw HumanWishlistCommandError.itemOwnershipMismatch
        }
        guard !item.isRedeemed else { throw HumanWishlistCommandError.alreadyRedeemed }
        guard item.cost > 0 else { throw HumanWishlistCommandError.invalidCost }
        let humanBalance = CoconutWalletService.balance(for: human, context: context)
        guard humanBalance >= item.cost else {
            throw HumanWishlistCommandError.insufficientCoconuts(missing: item.cost - humanBalance)
        }

        item.isRedeemed = true
        item.redeemedById = normalizedId(redeemedById)

        let ledger = careLedger.record(
            occurredAt: Date(),
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
        do {
            try wallet.apply(
                deltas: [
                    .human(
                        human,
                        delta: -item.cost,
                        entryKind: .spend,
                        source: .shop,
                        title: "兑换「\(item.title)」",
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
            try context.save()
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
        guard item.creatorId == human.id.uuidString else {
            throw HumanWishlistCommandError.itemOwnershipMismatch
        }
        let ledgerEvents = ledgerEvents(for: item, context: context)
        for event in ledgerEvents {
            context.delete(event)
        }
        let itemID = item.id
        context.delete(item)
        context.safeSave()
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
