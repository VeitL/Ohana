//
//  DomainEntityLinkRegistry.swift
//  Ohana
//
//  Feature-neutral taxonomy for raw entity links persisted by schedules,
//  ledgers, notifications, sync records, and backup payloads.
//

import Foundation

nonisolated struct DomainEntityLink: Equatable, Hashable {
    let rawType: String
    let rawId: String

    init(rawType: String, rawId: String) {
        self.rawType = rawType
        self.rawId = rawId
    }

    init(event: Event) {
        self.init(rawType: event.relatedEntityType, rawId: event.relatedEntityId)
    }

    var normalizedType: String {
        rawType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var trimmedId: String {
        rawId.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

nonisolated enum DomainMemberReference: Equatable, Hashable {
    case pet(UUID)
    case human(UUID)

    var id: UUID {
        switch self {
        case let .pet(id), let .human(id):
            id
        }
    }

    var rawKind: String {
        switch self {
        case .pet:
            EntityKind.pet.rawValue
        case .human:
            EntityKind.human.rawValue
        }
    }
}

nonisolated enum DomainEntityLinkRole: Equatable {
    case directPet
    case directHuman
    case directPlant
    case plantScoped
    case petFoodStock
    case petAutoFeeder
    case petWaterPlan
    case petInsurance
    case petMedicationPlan
    case petMedicationDose
    case humanNote
    case humanMedicationPlan
    case unscoped
    case unknown(String)

    var isMemberScoped: Bool {
        switch self {
        case .directPet, .directHuman, .petFoodStock, .petAutoFeeder, .petWaterPlan,
             .petInsurance, .petMedicationPlan, .petMedicationDose, .humanNote, .humanMedicationPlan:
            true
        case .directPlant, .plantScoped, .unscoped, .unknown:
            false
        }
    }

    var isPetScoped: Bool {
        switch self {
        case .directPet, .petFoodStock, .petAutoFeeder, .petWaterPlan, .petInsurance,
             .petMedicationPlan, .petMedicationDose:
            true
        case .directHuman, .directPlant, .plantScoped, .humanNote, .humanMedicationPlan, .unscoped, .unknown:
            false
        }
    }

    var isHumanScoped: Bool {
        switch self {
        case .directHuman, .humanNote, .humanMedicationPlan:
            true
        case .directPet, .directPlant, .plantScoped, .petFoodStock, .petAutoFeeder, .petWaterPlan,
             .petInsurance, .petMedicationPlan, .petMedicationDose, .unscoped, .unknown:
            false
        }
    }

    var isPlantScoped: Bool {
        switch self {
        case .directPlant, .plantScoped:
            true
        case .directPet, .directHuman, .petFoodStock, .petAutoFeeder, .petWaterPlan,
             .petInsurance, .petMedicationPlan, .petMedicationDose, .humanNote,
             .humanMedicationPlan, .unscoped, .unknown:
            false
        }
    }

    var unregisteredType: String? {
        if case let .unknown(rawType) = self { return rawType }
        return nil
    }
}

enum DomainEntityLinkRegistry {
    nonisolated static let petFoodStock = "pet_food_stock"
    nonisolated static let petAutoFeeder = "pet_auto_feeder"
    nonisolated static let petWaterPlan = "pet_water_plan"
    nonisolated static let petInsurance = "pet_insurance"
    nonisolated static let petMedicationPlan = MedicationEventLink.petMedicationPlan
    nonisolated static let petMedicationDose = MedicationEventLink.petMedicationDose
    nonisolated static let humanMedicationPlan = MedicationEventLink.humanMedicationPlan
    nonisolated static let humanNote = "human_note"

    nonisolated static func role(for link: DomainEntityLink) -> DomainEntityLinkRole {
        switch link.normalizedType {
        case "":
            .unscoped
        case EntityKind.pet.rawValue.lowercased(), "pet":
            .directPet
        case EntityKind.human.rawValue.lowercased(), "human":
            .directHuman
        case EntityKind.plant.rawValue.lowercased(), "plant":
            .directPlant
        case let rawType where rawType.hasPrefix("plant_"):
            .plantScoped
        case petFoodStock:
            .petFoodStock
        case petAutoFeeder:
            .petAutoFeeder
        case petWaterPlan:
            .petWaterPlan
        case petInsurance:
            .petInsurance
        case petMedicationPlan:
            .petMedicationPlan
        case petMedicationDose:
            .petMedicationDose
        case humanNote:
            .humanNote
        case humanMedicationPlan:
            .humanMedicationPlan
        default:
            .unknown(link.normalizedType)
        }
    }

    nonisolated static func role(for event: Event) -> DomainEntityLinkRole {
        role(for: DomainEntityLink(event: event))
    }

    nonisolated static func petIdFromCompoundStockId(_ rawId: String) -> UUID? {
        UUID(uuidString: rawId.split(separator: ":", maxSplits: 1).first.map(String.init) ?? rawId)
    }

    nonisolated static func plantId(for link: DomainEntityLink) -> UUID? {
        switch role(for: link) {
        case .directPlant, .plantScoped:
            UUID(uuidString: link.trimmedId)
        case .unscoped where !link.trimmedId.isEmpty:
            UUID(uuidString: link.trimmedId)
        case .directPet, .directHuman, .petFoodStock, .petAutoFeeder, .petWaterPlan,
             .petInsurance, .petMedicationPlan, .petMedicationDose, .humanNote,
             .humanMedicationPlan, .unscoped, .unknown:
            nil
        }
    }

    nonisolated static func plantId(for event: Event) -> UUID? {
        plantId(for: DomainEntityLink(event: event))
    }

    nonisolated static func resolvedId(for link: DomainEntityLink, role expectedRole: DomainEntityLinkRole) -> UUID? {
        guard role(for: link) == expectedRole else { return nil }
        return UUID(uuidString: link.trimmedId)
    }

    nonisolated static func affectedEntityId(for link: DomainEntityLink, role: DomainEntityLinkRole? = nil) -> UUID? {
        let resolvedRole = role ?? self.role(for: link)
        switch resolvedRole {
        case .petFoodStock:
            return petIdFromCompoundStockId(link.trimmedId)
        case .directPet, .directHuman, .directPlant, .plantScoped, .petAutoFeeder, .petWaterPlan,
             .petInsurance, .petMedicationPlan, .petMedicationDose, .humanNote, .humanMedicationPlan:
            return UUID(uuidString: link.trimmedId)
        case .unscoped, .unknown:
            return nil
        }
    }

    nonisolated static func link(_ link: DomainEntityLink, matches role: DomainEntityLinkRole, id: UUID) -> Bool {
        resolvedId(for: link, role: role) == id
    }
}
