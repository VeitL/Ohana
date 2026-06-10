//
//  FocusHomeReminderDeepLinkRouter.swift
//  Ohana
//
//  Maps local notification reminder payloads to the existing home feature routes.
//

import Foundation
import SwiftData

struct OhanaReminderRoutePayload {
    let reminderId: UUID?
    let notificationId: String?
    let eventId: UUID?
    let eventType: String?
    let relatedEntityType: String?
    let relatedEntityId: String?

    init?(userInfo: [AnyHashable: Any]?) {
        guard let userInfo else { return nil }
        self.init(value: { key in userInfo[key] as? String })
    }

    init?(userInfo: [String: Any]?) {
        guard let userInfo else { return nil }
        self.init(value: { key in userInfo[key] as? String })
    }

    private init?(value: (String) -> String?) {
        let reminderId = value("reminderId").flatMap(UUID.init(uuidString:))
        let notificationId = value("notificationId")
        let eventId = value("eventId").flatMap(UUID.init(uuidString:))
        let eventType = value("eventType")
        let relatedEntityType = value("relatedEntityType")
        let relatedEntityId = value("relatedEntityId")

        guard reminderId != nil || notificationId != nil || eventId != nil || relatedEntityId != nil else {
            return nil
        }
        self.reminderId = reminderId
        self.notificationId = notificationId
        self.eventId = eventId
        self.eventType = eventType
        self.relatedEntityType = relatedEntityType
        self.relatedEntityId = relatedEntityId
    }
}

enum FocusHomeReminderDestination {
    case petQuick(String, Pet)
    case petFeature(PetFeature, Pet)
    case petHealth(Pet, PetHealthInitialSection)
    case humanQuick(String, Human)
    case humanDetail(Human)
    case plant(Plant)
    case functionMenu(FMDest)
    case calendar(entityId: String?, humanId: String?)
}

enum FocusHomeReminderDeepLinkRouter {
    static func destination(
        for payload: OhanaReminderRoutePayload,
        reminders: [Reminder],
        events: [Event],
        pets: [Pet],
        humans: [Human],
        plants: [Plant],
        humanMedications: [HumanMedication]
    ) -> FocusHomeReminderDestination? {
        let reminder = reminder(for: payload, reminders: reminders)
        if let event = reminder?.event ?? event(for: payload, events: events) {
            return destination(
                for: event,
                pets: pets,
                humans: humans,
                plants: plants,
                humanMedications: humanMedications
            )
        }
        return fallbackDestination(for: payload, pets: pets, humans: humans, plants: plants)
    }

    private static func reminder(for payload: OhanaReminderRoutePayload, reminders: [Reminder]) -> Reminder? {
        if let reminderId = payload.reminderId,
           let reminder = reminders.first(where: { $0.id == reminderId }) {
            return reminder
        }
        if let notificationId = payload.notificationId,
           let reminder = reminders.first(where: { $0.notificationId == notificationId }) {
            return reminder
        }
        return nil
    }

    private static func event(for payload: OhanaReminderRoutePayload, events: [Event]) -> Event? {
        if let eventId = payload.eventId,
           let event = events.first(where: { $0.id == eventId }) {
            return event
        }
        return nil
    }

    static func destination(
        for event: Event,
        pets: [Pet],
        humans: [Human],
        plants _: [Plant],
        humanMedications: [HumanMedication]
    ) -> FocusHomeReminderDestination {
        let entityType = event.relatedEntityType.lowercased()

        if entityType == "human_medication",
           let medicationId = UUID(uuidString: event.relatedEntityId),
           let medication = humanMedications.first(where: { $0.id == medicationId }),
           let human = humans.first(where: { $0.id.uuidString == medication.humanId }) {
            return .humanQuick("humanMedication", human)
        }

        if isHumanEntity(entityType),
           let human = humans.first(where: { $0.id.uuidString == event.relatedEntityId }) {
            return humanDestination(for: event, human: human)
        }

        if entityType == "human_note",
           let human = humans.first(where: { $0.id.uuidString == event.relatedEntityId }) {
            return .humanQuick("humanNote", human)
        }

        if isPlantEntity(entityType) {
            AppFeatureRouteGuard.recordIntercept("reminderPlant")
            return .functionMenu(.growthRoadmap)
        }

        if let pet = pet(for: event, pets: pets) {
            return petDestination(for: event, pet: pet)
        }

        return calendarDestination(for: event)
    }

    private static func fallbackDestination(
        for payload: OhanaReminderRoutePayload,
        pets: [Pet],
        humans: [Human],
        plants _: [Plant]
    ) -> FocusHomeReminderDestination? {
        let entityType = payload.relatedEntityType?.lowercased() ?? ""
        guard let id = payload.relatedEntityId else { return nil }

        if isHumanEntity(entityType),
           let human = humans.first(where: { $0.id.uuidString == id }) {
            return .humanDetail(human)
        }
        if isPlantEntity(entityType) {
            AppFeatureRouteGuard.recordIntercept("reminderPlantFallback")
            return .functionMenu(.growthRoadmap)
        }
        if isPetEntity(entityType),
           let pet = pets.first(where: { $0.id.uuidString == id }) {
            return .petFeature(.basicInfo, pet)
        }
        return nil
    }

    private static func pet(for event: Event, pets: [Pet]) -> Pet? {
        let entityType = event.relatedEntityType.lowercased()
        if isPetEntity(entityType) ||
            entityType == FeedRuleMetadata.autoFeederEntityType ||
            entityType == WaterPlanWriter.entityType.lowercased() {
            return pets.first { $0.id.uuidString == event.relatedEntityId && !$0.hasPassedAway }
        }
        if entityType == FeedingPlanWriter.stockReminderEntityType {
            return pets.first { pet in
                let id = pet.id.uuidString
                return event.relatedEntityId == id || event.relatedEntityId.hasPrefix("\(id):")
            }
        }
        if entityType == PetMedicationDoseLogging.relatedEntityTypeMedication {
            guard let medicationId = UUID(uuidString: event.relatedEntityId) else { return nil }
            return pets.first { pet in
                !pet.hasPassedAway && pet.medications.contains(where: { $0.id == medicationId })
            }
        }
        if entityType == "pet_insurance" {
            guard let insuranceId = UUID(uuidString: event.relatedEntityId) else { return nil }
            return pets.first { pet in
                !pet.hasPassedAway && pet.insurances.contains(where: { $0.id == insuranceId })
            }
        }
        return nil
    }

    private static func petDestination(for event: Event, pet: Pet) -> FocusHomeReminderDestination {
        let eventType = EventType(rawValue: event.eventType)
        let entityType = event.relatedEntityType.lowercased()
        let text = normalizedText(for: event)

        if entityType == "pet_insurance" || eventType == .insurancePremium {
            return .functionMenu(.petInsurance(pet.persistentModelID))
        }
        if entityType == PetMedicationDoseLogging.relatedEntityTypeMedication || eventType == .petMedicationDose {
            return .petFeature(.medications, pet)
        }
        if eventType == .litterBox ||
            matchesAny(text, ["猫砂", "铲", "便便", "potty", "litter", "scoop", "toilet", "klo"]) {
            return .petQuick(sharedLitterKey(for: pet), pet)
        }
        if matchesAny(text, ["遛", "散步", "walk", "spazier"]) {
            return .petQuick("walk", pet)
        }
        if eventType == .grooming ||
            matchesAny(text, ["洗澡", "美容", "清洁", "鸟笼", "过滤", "滤", "保湿", "垫材", "groom", "bath", "shower", "clean", "cage", "filter", "mist", "substrate", "pflege"]) {
            return .petFeature(.hygiene, pet)
        }
        if eventType == .vaccine ||
            eventType == .externalDeworming ||
            eventType == .internalDeworming ||
            eventType == .health ||
            eventType == .vetVisit ||
            matchesAny(text, ["疫苗", "驱虫", "就医", "体检", "健康", "温湿度", "水温", "vaccine", "deworm", "vet", "health", "check"]) {
            return .petHealth(pet, .preventive)
        }
        if entityType == WaterPlanWriter.entityType.lowercased() ||
            matchesAny(text, ["喝水", "饮水", "补充饮水", "喂水", "换水", "water", "drink", "wasser"]) {
            return .petQuick("water", pet)
        }
        if entityType == FeedingPlanWriter.stockReminderEntityType ||
            entityType == FeedRuleMetadata.autoFeederEntityType ||
            eventType == .foodChange ||
            matchesAny(text, ["喂", "吃饭", "粮", "feed", "food", "meal", "futter"]) {
            return .petQuick("feed", pet)
        }
        if matchesAny(text, ["体重", "weight", "gewicht"]) {
            return .petFeature(.weight, pet)
        }
        if matchesAny(text, ["玩", "陪伴", "play", "spiel"]) {
            return .petQuick("play", pet)
        }
        return .petFeature(.basicInfo, pet)
    }

    private static func humanDestination(for event: Event, human: Human) -> FocusHomeReminderDestination {
        let eventType = EventType(rawValue: event.eventType)
        let text = normalizedText(for: event)

        if eventType == .medication || matchesAny(text, ["吃药", "用药", "medication", "pill", "medik"]) {
            return .humanQuick("humanMedication", human)
        }
        if matchesAny(text, ["体重", "weight", "gewicht"]) {
            return .humanQuick("humanWeight", human)
        }
        if matchesAny(text, ["运动", "锻炼", "workout", "training"]) {
            return .humanQuick("humanWorkout", human)
        }
        if matchesAny(text, ["花费", "支出", "expense", "ausgabe"]) {
            return .humanQuick("humanExpense", human)
        }
        if matchesAny(text, ["备注", "记录", "note", "notiz"]) {
            return .humanQuick("humanNote", human)
        }
        return .humanDetail(human)
    }

    private static func calendarDestination(for event: Event) -> FocusHomeReminderDestination {
        let entityType = event.relatedEntityType.lowercased()
        if isHumanEntity(entityType) {
            return .calendar(entityId: nil, humanId: event.relatedEntityId)
        }
        if isPetEntity(entityType) || isPlantEntity(entityType) {
            return .calendar(entityId: event.relatedEntityId, humanId: nil)
        }
        return .calendar(entityId: nil, humanId: nil)
    }

    private static func sharedLitterKey(for pet: Pet) -> String {
        pet.species.contains("猫") || pet.species.contains("兔") ? "litter" : "potty"
    }

    private static func normalizedText(for event: Event) -> String {
        "\(event.title) \(event.eventType) \(event.relatedEntityType)".lowercased()
    }

    private static func matchesAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0.lowercased()) }
    }

    private static func isPetEntity(_ raw: String) -> Bool {
        raw == EntityKind.pet.rawValue.lowercased() || raw == "pet"
    }

    private static func isHumanEntity(_ raw: String) -> Bool {
        raw == EntityKind.human.rawValue.lowercased() || raw == "human"
    }

    private static func isPlantEntity(_ raw: String) -> Bool {
        raw == EntityKind.plant.rawValue.lowercased() || raw == "plant"
    }
}
