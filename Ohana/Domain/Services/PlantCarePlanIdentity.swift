//
//  PlantCarePlanIdentity.swift
//  Ohana
//
//  Stable, title-independent identity for generated plant-care calendar plans.
//

import Foundation

nonisolated enum PlantCarePlanIdentity {
    /// Compatibility marker used by plan rows created before structured identity.
    static let legacyTitleMarker = "植物计划"

    private static let namespace = "ohana.plant-care-plan.v1"

    static func expectedEventID(plantID: UUID, careType: PlantCareType) -> UUID {
        deterministicUUID(
            for: [
                namespace,
                plantID.uuidString.lowercased(),
                careType.rawValue
            ].joined(separator: "|")
        )
    }

    static func isStructuredMatch(
        _ event: Event,
        plantID: UUID,
        careType: PlantCareType
    ) -> Bool {
        guard let careKind = TaskCareKind(plantCareType: careType) else { return false }
        return event.id == expectedEventID(plantID: plantID, careType: careType) &&
            event.relatedEntityType == EntityKind.plant.rawValue &&
            event.relatedEntityId == plantID.uuidString &&
            event.eventType == careType.eventType.rawValue &&
            event.taskCareKindRaw == careKind.rawValue &&
            event.isAllDay &&
            event.recurrenceDays > 0
    }

    static func isLegacyMatch(
        _ event: Event,
        plantID: UUID,
        careType: PlantCareType
    ) -> Bool {
        guard hasStrictPlanShape(event, plantID: plantID),
              event.eventType == careType.eventType.rawValue,
              event.title.contains(legacyTitleMarker) else {
            return false
        }
        guard !event.taskCareKindRaw.isEmpty else { return true }
        return TaskCareKind(rawValue: event.taskCareKindRaw)?.plantCareType == careType
    }

    /// A stored defaults pointer is one-time migration evidence even when an
    /// older generated title was localized or subsequently edited. This shape
    /// check intentionally stays separate from `isGeneratedPlan`: without the
    /// exact stored pointer, an ordinary user event must never be claimed.
    static func isStoredPointerMigrationEvidence(
        _ event: Event,
        plantID: UUID,
        careType: PlantCareType
    ) -> Bool {
        guard hasStrictPlanShape(event, plantID: plantID) else { return false }
        if !event.taskCareKindRaw.isEmpty {
            return TaskCareKind(rawValue: event.taskCareKindRaw)?.plantCareType == careType
        }
        return event.eventType == careType.eventType.rawValue
    }

    static func isOwnedPlan(
        _ event: Event,
        plantID: UUID,
        careType: PlantCareType
    ) -> Bool {
        isStructuredMatch(event, plantID: plantID, careType: careType) ||
            isLegacyMatch(event, plantID: plantID, careType: careType)
    }

    static func isGeneratedPlan(_ event: Event) -> Bool {
        guard let plantID = DomainEntityLinkRegistry.plantId(for: event) else { return false }
        return PlantCareCategory.schedulableCareTypes.contains { careType in
            isOwnedPlan(event, plantID: plantID, careType: careType)
        }
    }

    private static func hasStrictPlanShape(_ event: Event, plantID: UUID) -> Bool {
        event.relatedEntityType == EntityKind.plant.rawValue &&
            event.relatedEntityId == plantID.uuidString &&
            event.isAllDay &&
            event.recurrenceDays > 0
    }

    private static func deterministicUUID(for seed: String) -> UUID {
        var first = UInt64(1_469_598_103_934_665_603)
        var second = UInt64(780_984_778_246_553_632)
        for byte in seed.utf8 {
            first ^= UInt64(byte)
            first &*= 1_099_511_628_211
            second ^= UInt64(byte) &+ first
            second &*= 1_099_511_628_211
        }
        let raw = String(
            format: "%08X-%04X-%04X-%04X-%012llX",
            UInt32(truncatingIfNeeded: first),
            UInt16(truncatingIfNeeded: first >> 32),
            UInt16(truncatingIfNeeded: first >> 48),
            UInt16(truncatingIfNeeded: second),
            second & 0x0000_FFFF_FFFF_FFFF
        )
        return UUID(uuidString: raw)!
    }
}
