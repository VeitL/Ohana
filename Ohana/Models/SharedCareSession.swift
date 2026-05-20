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
    case pottyUnknown
    case litterScoop
    case litterChange
}

enum SharedCareAllocationMode: String, Codable, CaseIterable {
    case equal
    case unknown
}

enum SharedCareMetadata {
    static let sharedFeedNotePrefix = "ohana_shared_feed:"
    static let sharedWaterNotePrefix = "ohana_shared_water:"
    static let sharedLitterNotePrefix = "ohana_shared_litter:"
    static let unknownPottyNotePrefix = "ohana_shared_unknown_potty:"
    static let stockTotalKey = "stockTotal="
    static let stockOwnerKey = "stockOwner=1"

    static func note(prefix: String, sessionId: UUID, stockTotalGrams: Double? = nil, isStockOwner: Bool = false) -> String {
        var parts = ["\(prefix)\(sessionId.uuidString)"]
        if let stockTotalGrams {
            parts.append("\(stockTotalKey)\(Int(stockTotalGrams.rounded()))")
        }
        if isStockOwner {
            parts.append(stockOwnerKey)
        }
        return parts.joined(separator: " ")
    }

    static func stockDeductionGrams(from note: String) -> Double? {
        guard note.contains(stockOwnerKey),
              let token = note.split(separator: " ").first(where: { $0.hasPrefix(stockTotalKey) }) else {
            return nil
        }
        return Double(token.dropFirst(stockTotalKey.count))
    }
}

@Model
final class SharedCareSession {
    #Index<SharedCareSession>([\.date])
    var id: UUID = UUID()
    var date: Date = Date()
    var actionKindRaw: String = SharedCareActionKind.feeding.rawValue
    var executorId: String?
    var sourcePetId: String = ""
    var targetPetIdsRaw: String = ""
    var speciesRaw: String = ""
    var totalAmountGrams: Double = 0
    var totalAmountMl: Double = 0
    var allocationModeRaw: String = SharedCareAllocationMode.equal.rawValue
    var foodKindRaw: String = FeedFoodKind.dry.rawValue
    var stockOwnerPetId: String = ""
    var note: String = ""
    var createdAt: Date = Date()

    init(
        date: Date = Date(),
        actionKind: SharedCareActionKind = .feeding,
        executorId: String? = nil,
        sourcePetId: String = "",
        targetPetIds: [String] = [],
        species: String = "",
        totalAmountGrams: Double = 0,
        totalAmountMl: Double = 0,
        allocationMode: SharedCareAllocationMode = .equal,
        foodKind: FeedFoodKind = .dry,
        stockOwnerPetId: String = "",
        note: String = ""
    ) {
        self.id = UUID()
        self.date = date
        self.actionKindRaw = actionKind.rawValue
        self.executorId = executorId
        self.sourcePetId = sourcePetId
        self.targetPetIdsRaw = targetPetIds.joined(separator: "|")
        self.speciesRaw = species
        self.totalAmountGrams = totalAmountGrams
        self.totalAmountMl = totalAmountMl
        self.allocationModeRaw = allocationMode.rawValue
        self.foodKindRaw = foodKind.rawValue
        self.stockOwnerPetId = stockOwnerPetId
        self.note = note
        self.createdAt = Date()
    }

    var actionKind: SharedCareActionKind { SharedCareActionKind(rawValue: actionKindRaw) ?? .feeding }
    var allocationMode: SharedCareAllocationMode { SharedCareAllocationMode(rawValue: allocationModeRaw) ?? .equal }
    var foodKind: FeedFoodKind { FeedFoodKind(rawValue: foodKindRaw) ?? .dry }
    var targetPetIds: [String] {
        targetPetIdsRaw
            .split(separator: "|")
            .map(String.init)
            .filter { !$0.isEmpty }
    }
}

