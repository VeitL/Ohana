//
//  CoconutWalletModels.swift
//  Ohana
//
//  SwiftData-backed coconut wallet accounts and immutable ledger entries.
//

import Foundation
import SwiftData

enum CoconutWalletOwnerKind: String, Codable, CaseIterable {
    case human
    case pet
    case system
}

enum CoconutWalletEntryKind: String, Codable, CaseIterable {
    case openingBalance
    case reward
    case spend
    case refund
    case transferIn
    case transferOut
    case adjustment
    case legacyHistory
}

enum CoconutWalletSource: String, Codable, CaseIterable {
    case legacyUserDefaults
    case careEvent
    case familyTask
    case exchange
    case gacha
    case oasis
    case shop
    case onboarding
    case starterGift
    case importData
    case service
}

enum EconomyBudgetUsageScope: String, Codable, CaseIterable {
    case household
    case member
    case careObject
}

enum CoconutAccountKey {
    static let legacySystem = "system:legacy"

    static func human(_ id: UUID) -> String {
        human(id.uuidString)
    }

    static func human(_ id: String) -> String {
        "human:\(id)"
    }

    static func pet(_ id: UUID) -> String {
        pet(id.uuidString)
    }

    static func pet(_ id: String) -> String {
        "pet:\(id)"
    }

    static func system(_ id: String = "legacy") -> String {
        "system:\(id)"
    }

    static func key(ownerKind: CoconutWalletOwnerKind, ownerId: String) -> String {
        switch ownerKind {
        case .human:
            human(ownerId)
        case .pet:
            pet(ownerId)
        case .system:
            system(ownerId.isEmpty ? "legacy" : ownerId)
        }
    }
}

@Model
final class CoconutAccount {
    #Index<CoconutAccount>([\.accountKey], [\.ownerKindRaw, \.ownerId], [\.updatedAt])

    var id: UUID
    var accountKey: String
    var ownerKindRaw: String
    var ownerId: String
    var displayName: String
    var balance: Int
    var createdAt: Date
    var updatedAt: Date
    var metadataJSON: String

    init(
        id: UUID = UUID(),
        accountKey: String,
        ownerKind: CoconutWalletOwnerKind,
        ownerId: String,
        displayName: String,
        balance: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        metadataJSON: String = ""
    ) {
        self.id = id
        self.accountKey = accountKey
        self.ownerKindRaw = ownerKind.rawValue
        self.ownerId = ownerId
        self.displayName = displayName
        self.balance = balance
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.metadataJSON = metadataJSON
    }

    var ownerKind: CoconutWalletOwnerKind {
        CoconutWalletOwnerKind(rawValue: ownerKindRaw) ?? .system
    }
}

@Model
final class CoconutLedgerEntry {
    #Index<CoconutLedgerEntry>(
        [\.occurredAt],
        [\.accountKey, \.occurredAt],
        [\.transactionKey],
        [\.sourceModelName, \.sourceModelId]
    )

    var id: UUID
    var transactionKey: String
    var accountKey: String
    var ownerKindRaw: String
    var ownerId: String
    var ownerName: String
    var delta: Int
    var balanceBefore: Int
    var balanceAfter: Int
    var affectsBalance: Bool
    var entryKindRaw: String
    var sourceRaw: String
    var title: String
    var emoji: String
    var actorId: String?
    var actorName: String?
    var subjectKindRaw: String
    var subjectId: String?
    var sourceModelName: String
    var sourceModelId: String
    var careLedgerEventId: String?
    var metadataJSON: String
    var occurredAt: Date
    var createdAt: Date

    init(
        id: UUID = UUID(),
        transactionKey: String,
        accountKey: String,
        ownerKind: CoconutWalletOwnerKind,
        ownerId: String,
        ownerName: String,
        delta: Int,
        balanceBefore: Int,
        balanceAfter: Int,
        affectsBalance: Bool = true,
        entryKind: CoconutWalletEntryKind,
        source: CoconutWalletSource,
        title: String,
        emoji: String,
        actorId: String? = nil,
        actorName: String? = nil,
        subjectKind: CareLedgerSubjectKind = .system,
        subjectId: String? = nil,
        sourceModelName: String = "",
        sourceModelId: String = "",
        careLedgerEventId: String? = nil,
        metadataJSON: String = "",
        occurredAt: Date = Date(),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.transactionKey = transactionKey
        self.accountKey = accountKey
        self.ownerKindRaw = ownerKind.rawValue
        self.ownerId = ownerId
        self.ownerName = ownerName
        self.delta = delta
        self.balanceBefore = balanceBefore
        self.balanceAfter = balanceAfter
        self.affectsBalance = affectsBalance
        self.entryKindRaw = entryKind.rawValue
        self.sourceRaw = source.rawValue
        self.title = title
        self.emoji = emoji
        self.actorId = actorId
        self.actorName = actorName
        self.subjectKindRaw = subjectKind.rawValue
        self.subjectId = subjectId
        self.sourceModelName = sourceModelName
        self.sourceModelId = sourceModelId
        self.careLedgerEventId = careLedgerEventId
        self.metadataJSON = metadataJSON
        self.occurredAt = occurredAt
        self.createdAt = createdAt
    }

    var ownerKind: CoconutWalletOwnerKind {
        CoconutWalletOwnerKind(rawValue: ownerKindRaw) ?? .system
    }

    var entryKind: CoconutWalletEntryKind {
        CoconutWalletEntryKind(rawValue: entryKindRaw) ?? .adjustment
    }

    var source: CoconutWalletSource {
        CoconutWalletSource(rawValue: sourceRaw) ?? .service
    }

    func asCoconutLogEntry() -> CoconutLogEntry {
        CoconutLogEntry(
            id: id,
            emoji: emoji,
            title: title,
            amount: delta,
            date: occurredAt,
            actorId: ownerKind == .system ? actorId : ownerId,
            actorName: ownerKind == .system ? actorName : ownerName,
            economyReason: sourceRaw,
            budgetStage: entryKindRaw
        )
    }
}

@Model
final class EconomyBudgetUsageEvent {
    #Index<EconomyBudgetUsageEvent>(
        [\.dayKey, \.householdKey],
        [\.dayKey, \.scopeRaw, \.scopeKey],
        [\.createdAt]
    )

    var id: UUID
    var dayKey: String
    var householdKey: String
    var memberKey: String
    var careObjectKey: String
    var scopeRaw: String
    var scopeKey: String
    var growthXPUsed: Int
    var coconutUsed: Int
    var luckyCoconutUsed: Int
    var actionKey: String
    var source: String
    var metadataJSON: String
    var occurredAt: Date
    var createdAt: Date

    init(
        id: UUID = UUID(),
        dayKey: String,
        householdKey: String,
        memberKey: String,
        careObjectKey: String = "",
        scope: EconomyBudgetUsageScope,
        scopeKey: String,
        growthXPUsed: Int,
        coconutUsed: Int,
        luckyCoconutUsed: Int = 0,
        actionKey: String,
        source: String,
        metadataJSON: String = "",
        occurredAt: Date = Date(),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.dayKey = dayKey
        self.householdKey = householdKey
        self.memberKey = memberKey
        self.careObjectKey = careObjectKey
        self.scopeRaw = scope.rawValue
        self.scopeKey = scopeKey
        self.growthXPUsed = growthXPUsed
        self.coconutUsed = coconutUsed
        self.luckyCoconutUsed = luckyCoconutUsed
        self.actionKey = actionKey
        self.source = source
        self.metadataJSON = metadataJSON
        self.occurredAt = occurredAt
        self.createdAt = createdAt
    }

    var scope: EconomyBudgetUsageScope {
        EconomyBudgetUsageScope(rawValue: scopeRaw) ?? .household
    }
}
