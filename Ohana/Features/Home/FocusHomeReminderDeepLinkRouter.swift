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
    let petId: UUID?
    let humanId: UUID?
    let medicationId: UUID?
    let humanMedicationId: UUID?

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
        let petId = value("petId").flatMap(UUID.init(uuidString:))
        let humanId = value("humanId").flatMap(UUID.init(uuidString:))
        let medicationId = value("medicationId").flatMap(UUID.init(uuidString:))
        let humanMedicationId = value("humanMedicationId").flatMap(UUID.init(uuidString:))

        guard reminderId != nil ||
            notificationId != nil ||
            eventId != nil ||
            relatedEntityId != nil ||
            petId != nil ||
            humanId != nil ||
            medicationId != nil ||
            humanMedicationId != nil else {
            return nil
        }
        self.reminderId = reminderId
        self.notificationId = notificationId
        self.eventId = eventId
        self.eventType = eventType
        self.relatedEntityType = relatedEntityType
        self.relatedEntityId = relatedEntityId
        self.petId = petId
        self.humanId = humanId
        self.medicationId = medicationId
        self.humanMedicationId = humanMedicationId
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
        return fallbackDestination(
            for: payload,
            pets: pets,
            humans: humans,
            plants: plants,
            humanMedications: humanMedications
        )
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
        if let human = MemberLifecycleActiveScheduleResolver.humanOwner(
            for: event,
            humans: humans,
            humanMedications: humanMedications
        ) {
            return humanDestination(for: event, human: human)
        }

        if linkRole(for: event) == .directPlant {
            AppFeatureRouteGuard.recordIntercept("reminderPlant")
            return .functionMenu(.growthRoadmap)
        }

        if let pet = MemberLifecycleActiveScheduleResolver.petTarget(
            for: event,
            pets: pets,
            includePassedAway: false
        ) {
            return petDestination(for: event, pet: pet)
        }

        if let human = MemberLifecycleActiveScheduleResolver.humanInvolved(
            in: event,
            humans: humans,
            humanMedications: humanMedications,
            includePassedAway: false
        ) {
            return humanDestination(for: event, human: human)
        }

        return calendarDestination(for: event)
    }

    private static func fallbackDestination(
        for payload: OhanaReminderRoutePayload,
        pets: [Pet],
        humans: [Human],
        plants _: [Plant],
        humanMedications: [HumanMedication]
    ) -> FocusHomeReminderDestination? {
        if let humanMedicationId = payload.humanMedicationId,
           let medication = humanMedications.first(where: { $0.id == humanMedicationId }),
           let human = humans.first(where: { $0.id.uuidString == medication.humanId }) {
            return .humanQuick("humanMedication", human)
        }
        if let humanId = payload.humanId,
           let human = humans.first(where: { $0.id == humanId }) {
            return .humanQuick("humanMedication", human)
        }
        if let medicationId = payload.medicationId {
            for pet in pets where !pet.hasPassedAway && pet.medications.contains(where: { $0.id == medicationId }) {
                return .petFeature(.medications, pet)
            }
        }
        if let petId = payload.petId,
           let pet = pets.first(where: { $0.id == petId && !$0.hasPassedAway }) {
            return .petFeature(.medications, pet)
        }

        guard let relatedEntityType = payload.relatedEntityType,
              let relatedEntityId = payload.relatedEntityId else { return nil }
        let resolution = DomainSubjectResolver.resolve(
            request: DomainSubjectResolutionRequest(
                relatedEntityType: relatedEntityType,
                relatedEntityId: relatedEntityId
            ),
            catalog: subjectCatalog(pets: pets, humans: humans, humanMedications: humanMedications)
        )

        if case let .human(humanId) = resolution.owner,
           let human = humans.first(where: { $0.id == humanId }) {
            return .humanDetail(human)
        }
        if resolution.role == .directPlant {
            AppFeatureRouteGuard.recordIntercept("reminderPlantFallback")
            return .functionMenu(.growthRoadmap)
        }
        if case let .pet(petId) = resolution.owner,
           let pet = pets.first(where: { $0.id == petId }) {
            return .petFeature(.basicInfo, pet)
        }
        return nil
    }

    private static func petDestination(for event: Event, pet: Pet) -> FocusHomeReminderDestination {
        let eventType = EventType(rawValue: event.eventType)
        let role = linkRole(for: event)
        let text = normalizedText(for: event)

        if role == .petInsurance || eventType == .insurancePremium {
            return .functionMenu(.petInsurance(pet.persistentModelID))
        }
        if role == .petMedicationDose ||
            role == .petMedicationPlan ||
            eventType == .petMedication ||
            eventType == .petMedicationDose {
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
        if role == .petWaterPlan ||
            matchesAny(text, ["喝水", "饮水", "补充饮水", "喂水", "换水", "water", "drink", "wasser"]) {
            return .petQuick("water", pet)
        }
        if role == .petFoodStock ||
            role == .petAutoFeeder ||
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
        let link = DomainEntityLink(event: event)
        let role = DomainEntityLinkRegistry.role(for: link)
        if let humanId = DomainEntityLinkRegistry.resolvedId(for: link, role: .directHuman)
            ?? DomainEntityLinkRegistry.resolvedId(for: link, role: .humanNote) {
            return .calendar(entityId: nil, humanId: humanId.uuidString)
        }
        if let petId = DomainEntityLinkRegistry.resolvedId(for: link, role: .directPet) {
            return .calendar(entityId: petId.uuidString, humanId: nil)
        }
        if role.isPlantScoped,
           let plantId = DomainEntityLinkRegistry.plantId(for: link) {
            return .calendar(entityId: plantId.uuidString, humanId: nil)
        }
        return .calendar(entityId: nil, humanId: nil)
    }

    private static func sharedLitterKey(for pet: Pet) -> String {
        pet.species.contains("猫") || pet.species.contains("兔") ? "litter" : "potty"
    }

    private static func normalizedText(for event: Event) -> String {
        "\(event.title) \(event.eventType)".lowercased()
    }

    private static func matchesAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0.lowercased()) }
    }

    private static func linkRole(for event: Event) -> DomainEntityLinkRole {
        DomainEntityLinkRegistry.role(for: event)
    }

    private static func subjectCatalog(
        pets: [Pet],
        humans: [Human],
        humanMedications: [HumanMedication]
    ) -> DomainSubjectResolutionCatalog {
        DomainSubjectResolutionCatalog(
            pets: pets,
            petMedications: pets.flatMap(\.medications),
            humanMedications: humanMedications,
            insurances: pets.flatMap(\.insurances),
            humans: humans
        )
    }
}
