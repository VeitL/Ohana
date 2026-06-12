//
//  CoconutWalletFundingPlanner.swift
//  Ohana
//

import Foundation
import SwiftData

struct CoconutWalletFundingContribution {
    let human: Human
    let amount: Int
}

struct CoconutWalletFundingPlan {
    let contributions: [CoconutWalletFundingContribution]
    let missing: Int
}

struct CoconutHumanWalletMutation {
    let human: Human
    let delta: Int
    let entryKind: CoconutWalletEntryKind
    let source: CoconutWalletSource
    let title: String
    let emoji: String
    let actorId: String?
    let actorName: String?
    let subjectKind: CareLedgerSubjectKind
    let subjectId: String?
    let sourceModelName: String
    let sourceModelId: String
    let careLedgerEventId: String?
    let metadataJSON: String
    let transactionKey: String

    func walletDelta() -> CoconutWalletDelta {
        .human(
            human,
            delta: delta,
            entryKind: entryKind,
            source: source,
            title: title,
            emoji: emoji,
            actorId: actorId,
            actorName: actorName,
            subjectKind: subjectKind,
            subjectId: subjectId,
            sourceModelName: sourceModelName,
            sourceModelId: sourceModelId,
            careLedgerEventId: careLedgerEventId,
            metadataJSON: metadataJSON,
            transactionKey: transactionKey
        )
    }
}

enum CoconutWalletFundingPlanner {
    @MainActor
    static func humanCofundingPlan(
        cost: Int,
        primaryHuman: Human,
        context: ModelContext,
        logPrefix: String
    ) -> CoconutWalletFundingPlan {
        var remaining = cost
        var contributions: [CoconutWalletFundingContribution] = []
        let primaryContribution = min(remaining, max(0, CoconutWalletService.balance(for: primaryHuman, context: context)))
        if primaryContribution > 0 {
            contributions.append(CoconutWalletFundingContribution(human: primaryHuman, amount: primaryContribution))
            remaining -= primaryContribution
        }
        guard remaining > 0 else {
            return CoconutWalletFundingPlan(contributions: contributions, missing: 0)
        }

        let otherHumans: [Human]
        do {
            otherHumans = try context.fetch(FetchDescriptor<Human>())
        } catch {
            OhanaLog.warning(
                "[\(logPrefix)] failed to fetch cofunding humans: \(error.localizedDescription)",
                category: "Economy"
            )
            return CoconutWalletFundingPlan(contributions: contributions, missing: remaining)
        }

        let contributors = otherHumans
            .filter { $0.id != primaryHuman.id && EconomyWalletWritePolicy.canWrite($0) }
            .sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
        for human in contributors where remaining > 0 {
            let available = max(0, CoconutWalletService.balance(for: human, context: context))
            let contribution = min(remaining, available)
            guard contribution > 0 else { continue }
            contributions.append(CoconutWalletFundingContribution(human: human, amount: contribution))
            remaining -= contribution
        }
        return CoconutWalletFundingPlan(contributions: contributions, missing: remaining)
    }
}

enum CoconutWalletMutationWriter {
    @discardableResult
    @MainActor
    static func applyHumanMutations(
        _ mutations: [CoconutHumanWalletMutation],
        wallet: CoconutWalletManaging,
        context: ModelContext,
        save: Bool,
        postsRewardFeedback: Bool,
        updatesProjection: Bool,
        projectionManager: QuestManager?
    ) throws -> [CoconutLedgerEntry] {
        try wallet.apply(
            deltas: mutations.map { $0.walletDelta() },
            context: context,
            save: save,
            postsRewardFeedback: postsRewardFeedback,
            updatesProjection: updatesProjection,
            projectionManager: projectionManager
        )
    }
}
