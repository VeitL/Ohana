//
//  HumanHealthCondition.swift
//  Ohana
//
//  Local-first condition tracking and self-reported observations for Humans.
//

import Foundation
import SwiftData

nonisolated enum HumanHealthConditionCategory: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case mentalHealth
    case thyroid
    case allergy
    case hairAndScalp
    case autoimmune
    case metabolic
    case cardiovascular
    case respiratory
    case digestive
    case neurological
    case musculoskeletal
    case skin
    case other

    var id: String { rawValue }
}

nonisolated enum HumanHealthTrackingStatus: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case active
    case monitoring
    case stable
    case resolved

    var id: String { rawValue }
}

nonisolated enum HumanMedicationResponse: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case unknown
    case helpful
    case neutral
    case worse

    var id: String { rawValue }
}

@Model
final class HumanHealthCondition {
    var id: UUID
    var humanId: String
    var name: String
    var categoryRaw: String
    var trackingStatusRaw: String
    var startedOn: Date?
    var carePlan: String
    var notes: String
    var linkedMedicationIDsRaw: String
    var linkedMetricKeysRaw: String
    var recordedByHumanId: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        humanId: String,
        name: String,
        category: HumanHealthConditionCategory = .other,
        trackingStatus: HumanHealthTrackingStatus = .active,
        startedOn: Date? = nil,
        carePlan: String = "",
        notes: String = "",
        linkedMedicationIDs: [UUID] = [],
        linkedMetricKeys: [String] = [],
        recordedByHumanId: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.humanId = humanId
        self.name = name
        categoryRaw = category.rawValue
        trackingStatusRaw = trackingStatus.rawValue
        self.startedOn = startedOn
        self.carePlan = carePlan
        self.notes = notes
        linkedMedicationIDsRaw = HumanHealthListCodec.encodeUUIDs(linkedMedicationIDs)
        linkedMetricKeysRaw = HumanHealthListCodec.encodeStrings(linkedMetricKeys)
        self.recordedByHumanId = recordedByHumanId
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    var category: HumanHealthConditionCategory {
        get { HumanHealthConditionCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var trackingStatus: HumanHealthTrackingStatus {
        get { HumanHealthTrackingStatus(rawValue: trackingStatusRaw) ?? .active }
        set { trackingStatusRaw = newValue.rawValue }
    }

    var linkedMedicationIDs: [UUID] {
        get { HumanHealthListCodec.decodeUUIDs(linkedMedicationIDsRaw) }
        set { linkedMedicationIDsRaw = HumanHealthListCodec.encodeUUIDs(newValue) }
    }

    var linkedMetricKeys: [String] {
        get { HumanHealthListCodec.decodeStrings(linkedMetricKeysRaw) }
        set { linkedMetricKeysRaw = HumanHealthListCodec.encodeStrings(newValue) }
    }
}

@Model
final class HumanHealthObservation {
    var id: UUID
    var humanId: String
    var conditionId: String
    var recordedAt: Date
    var severity: Int
    var moodScore: Int?
    var sleepHours: Double?
    var symptomTagsRaw: String
    var possibleTriggers: String
    var careActions: String
    var medicationResponseRaw: String
    var sideEffects: String
    var notes: String
    var recordedByHumanId: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        humanId: String,
        conditionId: String,
        recordedAt: Date = Date(),
        severity: Int,
        moodScore: Int? = nil,
        sleepHours: Double? = nil,
        symptomTags: [String] = [],
        possibleTriggers: String = "",
        careActions: String = "",
        medicationResponse: HumanMedicationResponse = .unknown,
        sideEffects: String = "",
        notes: String = "",
        recordedByHumanId: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.humanId = humanId
        self.conditionId = conditionId
        self.recordedAt = recordedAt
        self.severity = max(0, min(10, severity))
        self.moodScore = moodScore.map { max(1, min(10, $0)) }
        self.sleepHours = sleepHours.map { $0.isFinite ? max(0, min(24, $0)) : 0 }
        symptomTagsRaw = HumanHealthListCodec.encodeStrings(symptomTags)
        self.possibleTriggers = possibleTriggers
        self.careActions = careActions
        medicationResponseRaw = medicationResponse.rawValue
        self.sideEffects = sideEffects
        self.notes = notes
        self.recordedByHumanId = recordedByHumanId
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    var symptomTags: [String] {
        get { HumanHealthListCodec.decodeStrings(symptomTagsRaw) }
        set { symptomTagsRaw = HumanHealthListCodec.encodeStrings(newValue) }
    }

    var medicationResponse: HumanMedicationResponse {
        get { HumanMedicationResponse(rawValue: medicationResponseRaw) ?? .unknown }
        set { medicationResponseRaw = newValue.rawValue }
    }
}

private nonisolated enum HumanHealthListCodec {
    static func encodeUUIDs(_ values: [UUID]) -> String {
        encodeStrings(values.map(\.uuidString))
    }

    static func decodeUUIDs(_ raw: String) -> [UUID] {
        decodeStrings(raw).compactMap(UUID.init(uuidString:))
    }

    static func encodeStrings(_ values: [String]) -> String {
        let normalized = uniqueNonempty(values)
        guard let data = try? JSONEncoder().encode(normalized),
              let encoded = String(data: data, encoding: .utf8)
        else { return "[]" }
        return encoded
    }

    static func decodeStrings(_ raw: String) -> [String] {
        guard let data = raw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return uniqueNonempty(decoded)
    }

    private static func uniqueNonempty(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed).inserted else { continue }
            result.append(trimmed)
        }
        return result
    }
}
