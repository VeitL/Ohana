//
//  SharedCareSession.swift
//  Ohana
//
//  One real-world care action that applies to multiple same-species pets.
//

import Foundation
import SwiftData

enum SharedCareActionKind: String, Codable, CaseIterable {
    case feeding
    case watering
    case potty
    case pottyUnknown
    case hygiene
    case litterScoop
    case litterChange
    case waterChange
    case filterClean
    case cageCleaning
    case freeFlight
    case misting
    case substrateChange
    case play
    case walk
    case expense
}

enum SharedCareAllocationMode: String, Codable, CaseIterable {
    case equal
    case unknown
}

nonisolated enum SharedCareParticipantIDs {
    static func normalized(_ ids: [String], preferredFirst: String? = nil) -> [String] {
        var result: [String] = []
        func append(_ raw: String?) {
            let id = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !id.isEmpty, !result.contains(id) else { return }
            result.append(id)
        }
        append(preferredFirst)
        ids.forEach { append($0) }
        return result
    }

    static func encode(_ ids: [String], preferredFirst: String? = nil) -> String {
        normalized(ids, preferredFirst: preferredFirst).joined(separator: "|")
    }

    static func decode(_ raw: String, fallback: String? = nil) -> [String] {
        normalized(raw.split(separator: "|").map(String.init), preferredFirst: fallback)
    }
}

enum SharedCareMetadata {
    static let legacyMetadataMarker = "ohana_shared_"
    static let feedNotePrefix = "ohana_shared_feed:"
    static let waterNotePrefix = "ohana_shared_water:"
    static let litterNotePrefix = "ohana_shared_litter:"
    static let unknownPottyNotePrefix = "ohana_shared_unknown_potty:"
    static let careNotePrefix = "ohana_shared_care:"
    static let walkNotePrefix = "ohana_shared_walk:"
    static let expenseNotePrefix = "ohana_shared_expense:"
    static let stockTotalKey = "stockTotal="
    static let stockOwnerKey = "stockOwner=1"
    static let targetCountKey = "targets="
    private static let metadataNotePrefixes = [
        feedNotePrefix,
        waterNotePrefix,
        litterNotePrefix,
        unknownPottyNotePrefix,
        careNotePrefix,
        walkNotePrefix,
        expenseNotePrefix
    ]

    // Backward-compatibility helper for reading or constructing legacy fixtures only.
    // New shared-care writes store machine facts on SharedCareSession fields.
    static func legacyEncodedNote(
        prefix: String,
        sessionId: UUID,
        stockTotalGrams: Double? = nil,
        isStockOwner: Bool = false,
        targetCount: Int? = nil,
        visibleNote: String = ""
    ) -> String {
        var parts = ["\(prefix)\(sessionId.uuidString)"]
        if let stockTotalGrams {
            parts.append("\(stockTotalKey)\(Int(stockTotalGrams.rounded()))")
        }
        if isStockOwner {
            parts.append(stockOwnerKey)
        }
        if let targetCount, targetCount > 0 {
            parts.append("\(targetCountKey)\(targetCount)")
        }
        let cleanVisibleNote = visibleNote.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanVisibleNote.isEmpty {
            parts.append(cleanVisibleNote)
        }
        return parts.joined(separator: " ")
    }

    static func userNoteForStorage(_ note: String) -> String {
        visibleNote(note).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func hasLegacyMetadata(_ note: String) -> Bool {
        metadataToken(in: note) != nil
    }

    static func legacySessionId(from note: String) -> UUID? {
        guard let token = metadataToken(in: note),
              let prefix = metadataNotePrefixes.first(where: { token.hasPrefix($0) }) else {
            return nil
        }
        return UUID(uuidString: String(token.dropFirst(prefix.count)))
    }

    static func isStockOwner(_ note: String) -> Bool {
        note.split(separator: " ").contains(Substring(stockOwnerKey))
    }

    static func visibleNote(_ note: String) -> String {
        let parts = note
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        guard let metadataToken = parts.first,
              metadataNotePrefixes.contains(where: { metadataToken.hasPrefix($0) })
        else {
            return note
        }

        return parts
            .dropFirst()
            .filter { !$0.hasPrefix(stockTotalKey) && !$0.hasPrefix(targetCountKey) && $0 != stockOwnerKey }
            .joined(separator: " ")
    }

    static func targetCount(from note: String) -> Int? {
        guard let token = note.split(separator: " ").first(where: { $0.hasPrefix(targetCountKey) }) else {
            return nil
        }
        return Int(token.dropFirst(targetCountKey.count))
    }

    static func targetCount(session: SharedCareSession?, legacyNote: String) -> Int? {
        if let count = session?.targetPetIds.count, count > 0 {
            return count
        }
        return targetCount(from: legacyNote)
    }

    static func stockDeductionGrams(from note: String) -> Double? {
        guard note.contains(stockOwnerKey),
              let token = note.split(separator: " ").first(where: { $0.hasPrefix(stockTotalKey) }) else {
            return nil
        }
        return Double(token.dropFirst(stockTotalKey.count))
    }

    static func stockTotalGrams(from note: String) -> Double? {
        guard let token = note.split(separator: " ").first(where: { $0.hasPrefix(stockTotalKey) }) else {
            return nil
        }
        return Double(token.dropFirst(stockTotalKey.count))
    }

    private static func metadataToken(in note: String) -> String? {
        let parts = note
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        guard let first = parts.first,
              metadataNotePrefixes.contains(where: { first.hasPrefix($0) }) else {
            return nil
        }
        return first
    }
}

@Model
final class SharedCareSession {
    #Index<SharedCareSession>([\.date])
    var id: UUID = UUID()
    var date: Date = Date()
    var actionKindRaw: String = SharedCareActionKind.feeding.rawValue
    var executorId: String?
    var executorIdsRaw: String = ""
    var sourcePetId: String = ""
    var targetPetIdsRaw: String = ""
    var speciesRaw: String = ""
    var totalAmountGrams: Double = 0
    var totalAmountMl: Double = 0
    var totalExpenseAmount: Double = 0
    var expenseCategoryRaw: String = ExpenseCategory.other.rawValue
    var currencyCode: String = ""
    var allocationModeRaw: String = SharedCareAllocationMode.equal.rawValue
    var foodKindRaw: String = FeedFoodKind.dry.rawValue
    var stockOwnerPetId: String = ""
    var primaryLegacyModelName: String = ""
    var primaryLegacyModelId: String = ""
    var note: String = ""
    var createdAt: Date = Date()

    init(
        date: Date = Date(),
        actionKind: SharedCareActionKind = .feeding,
        executorId: String? = nil,
        executorIds: [String] = [],
        sourcePetId: String = "",
        targetPetIds: [String] = [],
        species: String = "",
        totalAmountGrams: Double = 0,
        totalAmountMl: Double = 0,
        totalExpenseAmount: Double = 0,
        expenseCategory: ExpenseCategory = .other,
        currencyCode: String = "",
        allocationMode: SharedCareAllocationMode = .equal,
        foodKind: FeedFoodKind = .dry,
        stockOwnerPetId: String = "",
        primaryLegacyModelName: String = "",
        primaryLegacyModelId: String = "",
        note: String = ""
    ) {
        self.id = UUID()
        self.date = date
        self.actionKindRaw = actionKind.rawValue
        let normalizedExecutorIds = SharedCareParticipantIDs.normalized(executorIds, preferredFirst: executorId)
        self.executorId = normalizedExecutorIds.first ?? executorId
        self.executorIdsRaw = SharedCareParticipantIDs.encode(normalizedExecutorIds)
        self.sourcePetId = sourcePetId
        self.targetPetIdsRaw = targetPetIds.joined(separator: "|")
        self.speciesRaw = species
        self.totalAmountGrams = totalAmountGrams
        self.totalAmountMl = totalAmountMl
        self.totalExpenseAmount = totalExpenseAmount
        self.expenseCategoryRaw = expenseCategory.rawValue
        self.currencyCode = currencyCode
        self.allocationModeRaw = allocationMode.rawValue
        self.foodKindRaw = foodKind.rawValue
        self.stockOwnerPetId = stockOwnerPetId
        self.primaryLegacyModelName = primaryLegacyModelName
        self.primaryLegacyModelId = primaryLegacyModelId
        self.note = note
        self.createdAt = Date()
    }

    var actionKind: SharedCareActionKind { SharedCareActionKind(rawValue: actionKindRaw) ?? .feeding }
    var allocationMode: SharedCareAllocationMode { SharedCareAllocationMode(rawValue: allocationModeRaw) ?? .equal }
    var foodKind: FeedFoodKind { FeedFoodKind(rawValue: foodKindRaw) ?? .dry }
    var expenseCategory: ExpenseCategory { ExpenseCategory(rawValue: expenseCategoryRaw) ?? .other }
    var executorIds: [String] {
        SharedCareParticipantIDs.decode(executorIdsRaw, fallback: executorId)
    }

    func setExecutorIds(_ ids: [String], primaryExecutorId: String? = nil) {
        let normalized = SharedCareParticipantIDs.normalized(ids, preferredFirst: primaryExecutorId ?? executorId)
        executorId = normalized.first
        executorIdsRaw = SharedCareParticipantIDs.encode(normalized)
    }

    var targetPetIds: [String] {
        targetPetIdsRaw
            .split(separator: "|")
            .map(String.init)
            .filter { !$0.isEmpty }
    }
}
