//
//  CoconutWalletService+DeveloperOverride.swift
//  Ohana
//
//  Developer-only wallet account overrides that intentionally skip ledger entries.
//

import Foundation
import SwiftData

extension CoconutWalletService {
    static func setDeveloperOverrideBalance(
        amount rawAmount: Int,
        for human: Human?,
        displayName: String,
        context: ModelContext
    ) {
        let amount = max(0, rawAmount)
        let accountKey = human.map { CoconutAccountKey.human($0.id) } ?? CoconutAccountKey.legacySystem
        let ownerKind: CoconutWalletOwnerKind = human == nil ? .system : .human
        let ownerId = human?.id.uuidString ?? ""
        let now = Date()

        if let account = account(accountKey: accountKey, context: context) {
            account.ownerKindRaw = ownerKind.rawValue
            account.ownerId = ownerId
            account.displayName = displayName
            account.balance = amount
            account.updatedAt = now
        } else {
            context.insert(CoconutAccount(
                accountKey: accountKey,
                ownerKind: ownerKind,
                ownerId: ownerId,
                displayName: displayName,
                balance: amount,
                createdAt: now,
                updatedAt: now,
                metadataJSON: "{\"source\":\"settings.coconut.test\"}"
            ))
        }

        human?.coconutBalance = amount
    }

    private static func account(accountKey: String, context: ModelContext) -> CoconutAccount? {
        var descriptor = FetchDescriptor<CoconutAccount>(
            predicate: #Predicate<CoconutAccount> { $0.accountKey == accountKey }
        )
        descriptor.fetchLimit = 1
        do {
            return try context.fetch(descriptor).first
        } catch {
            OhanaLog.warning(
                "CoconutWalletService developer override failed to fetch account: \(error.localizedDescription)",
                category: "Economy"
            )
            return nil
        }
    }
}
