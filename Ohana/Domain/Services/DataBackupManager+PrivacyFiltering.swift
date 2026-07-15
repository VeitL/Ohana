//
//  DataBackupManager+PrivacyFiltering.swift
//  Ohana
//
//  Restricted external-backup filters for Human health content.
//

nonisolated extension DataBackupManager {
    static func isHumanHealthEvent(_ event: Event) -> Bool {
        let role = DomainEntityLinkRegistry.role(for: event)
        switch role {
        case .humanMedicationPlan, .humanNote:
            return true
        case .directHuman:
            switch event.eventType {
            case EventType.birthday.rawValue, EventType.anniversary.rawValue:
                return false
            default:
                return true
            }
        case .directPet, .directPlant, .plantScoped, .petFoodStock,
             .petAutoFeeder, .petWaterPlan, .petInsurance,
             .petMedicationPlan, .petMedicationDose, .unscoped, .unknown:
            return event.eventType == EventType.medication.rawValue
        }
    }

    static func isHumanHealthLedgerEvent(_ event: CareLedgerEvent) -> Bool {
        if event.subjectKind == CareLedgerSubjectKind.human.rawValue {
            return true
        }
        guard event.actorKind == CareLedgerActorKind.human.rawValue else { return false }
        switch event.eventKindEnum {
        case .health, .weight, .medication, .workout:
            return true
        default:
            return false
        }
    }
}
