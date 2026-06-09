import Foundation
import SwiftData

enum CoconutExchangeError: LocalizedError {
    case sameReceiver
    case insufficientBalance
    case invalidReceiver
    case notPending
    case notSender
    case notReceiver

    var errorDescription: String? {
        switch self {
        case .sameReceiver:
            return "不能发给自己。"
        case .insufficientBalance:
            return "椰子余额不足。"
        case .invalidReceiver:
            return "请选择一个家庭成员。"
        case .notPending:
            return "这个兑换已经处理。"
        case .notSender:
            return "只有发起人可以取消。"
        case .notReceiver:
            return "只有接收人可以确认。"
        }
    }
}

enum CoconutExchangeService {
    @MainActor
    @discardableResult
    static func createRequest(
        sender: Human,
        receiver: Human,
        option: CoconutExchangeOption,
        note: String,
        context: ModelContext
    ) throws -> CoconutExchangeRequest {
        guard sender.id != receiver.id else { throw CoconutExchangeError.sameReceiver }
        guard sender.coconutBalance >= option.coconutCost else { throw CoconutExchangeError.insufficientBalance }

        let request = CoconutExchangeRequest(
            senderId: sender.id.uuidString,
            senderName: sender.name,
            receiverId: receiver.id.uuidString,
            receiverName: receiver.name,
            coconutCost: option.coconutCost,
            currencyCode: option.currencyCode,
            localAmount: option.localAmount,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        context.insert(request)

        let ledger = recordLedger(
            request,
            action: "coconutExchangeCreated",
            actor: sender,
            delta: -option.coconutCost,
            context: context,
            save: false
        )
        try CoconutWalletService.apply(
            deltas: [
                .human(
                    sender,
                    delta: -option.coconutCost,
                    entryKind: .spend,
                    source: .exchange,
                    title: "货币兑换申请",
                    emoji: "💱",
                    actorId: sender.id.uuidString,
                    actorName: sender.name,
                    subjectKind: .household,
                    subjectId: nil,
                    sourceModelName: "CoconutExchangeRequest",
                    sourceModelId: request.id.uuidString,
                    careLedgerEventId: ledger.id.uuidString,
                    metadataJSON: "{\"exchangeId\":\"\(request.id.uuidString)\",\"status\":\"\(request.status.rawValue)\"}",
                    transactionKey: "exchange:\(request.id.uuidString):created"
                )
            ],
            context: context,
            save: false
        )
        context.safeSave()
        return request
    }

    @MainActor
    static func confirm(
        _ request: CoconutExchangeRequest,
        by receiver: Human,
        context: ModelContext
    ) throws {
        guard request.status == .pending else { throw CoconutExchangeError.notPending }
        guard request.receiverId == receiver.id.uuidString else { throw CoconutExchangeError.notReceiver }

        request.status = .confirmed
        request.confirmedAt = Date()
        request.updatedAt = Date()
        recordLedger(
            request,
            action: "coconutExchangeConfirmed",
            actor: receiver,
            delta: 0,
            context: context,
            save: false
        )
        context.safeSave()
    }

    @MainActor
    static func cancel(
        _ request: CoconutExchangeRequest,
        by sender: Human,
        context: ModelContext
    ) throws {
        guard request.status == .pending else { throw CoconutExchangeError.notPending }
        guard request.senderId == sender.id.uuidString else { throw CoconutExchangeError.notSender }

        request.status = .cancelled
        request.cancelledAt = Date()
        request.updatedAt = Date()
        let ledger = recordLedger(
            request,
            action: "coconutExchangeCancelled",
            actor: sender,
            delta: request.coconutCost,
            context: context,
            save: false
        )
        try CoconutWalletService.apply(
            deltas: [
                .human(
                    sender,
                    delta: request.coconutCost,
                    entryKind: .refund,
                    source: .exchange,
                    title: "货币兑换取消退款",
                    emoji: "↩️",
                    actorId: sender.id.uuidString,
                    actorName: sender.name,
                    subjectKind: .household,
                    subjectId: nil,
                    sourceModelName: "CoconutExchangeRequest",
                    sourceModelId: request.id.uuidString,
                    careLedgerEventId: ledger.id.uuidString,
                    metadataJSON: "{\"exchangeId\":\"\(request.id.uuidString)\",\"status\":\"\(request.status.rawValue)\"}",
                    transactionKey: "exchange:\(request.id.uuidString):cancelled"
                )
            ],
            context: context,
            save: false
        )
        context.safeSave()
    }

    @MainActor
    @discardableResult
    private static func recordLedger(
        _ request: CoconutExchangeRequest,
        action: String,
        actor: Human,
        delta: Int,
        context: ModelContext,
        save: Bool
    ) -> CareLedgerEvent {
        let amountText = CoconutExchangeOption.format(request.localAmount, currencyCode: request.currencyCode)
        return CareLedgerService.record(
            occurredAt: Date(),
            actorKind: .human,
            actorId: actor.id.uuidString,
            subjectKind: .household,
            subjectId: nil,
            eventKind: .coconut,
            actionType: action,
            amountValue: request.localAmount,
            amountUnit: request.currencyCode,
            note: "\(request.senderName) → \(request.receiverName) · \(amountText)",
            source: .economy,
            legacyModelName: "CoconutExchangeRequest",
            legacyModelId: request.id.uuidString,
            coconutDelta: delta,
            metadataJSON: "{\"exchangeId\":\"\(request.id.uuidString)\",\"status\":\"\(request.status.rawValue)\"}",
            context: context,
            save: save
        )
    }
}
