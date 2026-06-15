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
        case .directPlant, .unscoped, .unknown:
            false
        }
    }

    var isPetScoped: Bool {
        switch self {
        case .directPet, .petFoodStock, .petAutoFeeder, .petWaterPlan, .petInsurance,
             .petMedicationPlan, .petMedicationDose:
            true
        case .directHuman, .directPlant, .humanNote, .humanMedicationPlan, .unscoped, .unknown:
            false
        }
    }

    var isHumanScoped: Bool {
        switch self {
        case .directHuman, .humanNote, .humanMedicationPlan:
            true
        case .directPet, .directPlant, .petFoodStock, .petAutoFeeder, .petWaterPlan,
             .petInsurance, .petMedicationPlan, .petMedicationDose, .unscoped, .unknown:
            false
        }
    }
}

enum DomainEntityLinkRegistry {
    nonisolated static let petFoodStock = "pet_food_stock"
    nonisolated static let petAutoFeeder = "pet_auto_feeder"
    nonisolated static let petWaterPlan = "pet_water_plan"
    nonisolated static let petInsurance = "pet_insurance"
    nonisolated static let petMedicationPlan = "pet_medication_plan"
    nonisolated static let petMedicationDose = "pet_medication"
    nonisolated static let humanMedicationPlan = "human_medication"
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

    nonisolated static func petIdFromCompoundStockId(_ rawId: String) -> UUID? {
        UUID(uuidString: rawId.split(separator: ":", maxSplits: 1).first.map(String.init) ?? rawId)
    }
}
