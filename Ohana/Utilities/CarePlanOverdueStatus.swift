//
//  CarePlanOverdueStatus.swift
//  Ohana
//
//  Shared overdue-plan detection for pet care surfaces.
//

import Foundation

struct CarePlanOverdueStatus: Equatable {
    let title: String
    let actionType: String
    let scheduledAt: Date
    let daysOverdue: Int
    let reminderId: UUID?
    let eventId: UUID?

    var compactText: String {
        daysOverdue > 0 ? "逾期\(daysOverdue)天" : "逾期"
    }

    var signature: String {
        let reminder = reminderId?.uuidString ?? "cycle"
        let event = eventId?.uuidString ?? "cycle"
        return "\(actionType):\(reminder):\(event):\(Int(scheduledAt.timeIntervalSince1970)):\(daysOverdue)"
    }
}

enum CarePlanOverdueStatusCalculator {
    static func petWarning(
        for pet: Pet,
        events: [Event],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> CarePlanOverdueStatus? {
        allWarnings(for: pet, events: events, now: now, calendar: calendar).first
    }

    static func warning(
        for actionType: String,
        pet: Pet,
        events: [Event],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> CarePlanOverdueStatus? {
        let accepted = acceptedActionTypes(for: actionType)
        return allWarnings(for: pet, events: events, now: now, calendar: calendar)
            .first { accepted.contains($0.actionType) }
    }

    static func homeSignature(
        for pet: Pet,
        events: [Event],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        petWarning(for: pet, events: events, now: now, calendar: calendar)?.signature ?? "ok"
    }

    static func humanWarning(
        for human: Human,
        events: [Event],
        medications: [HumanMedication],
        logs: [HumanMedicationLog],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> CarePlanOverdueStatus? {
        humanWarnings(
            for: human,
            events: events,
            medications: medications,
            logs: logs,
            now: now,
            calendar: calendar
        ).first
    }

    static func humanMedicationWarning(
        for human: Human,
        medications: [HumanMedication],
        logs: [HumanMedicationLog],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> CarePlanOverdueStatus? {
        humanMedicationWarnings(for: human, medications: medications, logs: logs, now: now, calendar: calendar).first
    }

    static func homeSignature(
        for human: Human,
        events: [Event],
        medications: [HumanMedication],
        logs: [HumanMedicationLog],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        humanWarning(
            for: human,
            events: events,
            medications: medications,
            logs: logs,
            now: now,
            calendar: calendar
        )?.signature ?? "ok"
    }

    static func plantWarning(
        for plant: Plant,
        events: [Event],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> CarePlanOverdueStatus? {
        plantWarnings(for: plant, events: events, now: now, calendar: calendar).first
    }

    static func homeSignature(
        for plant: Plant,
        events: [Event],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        plantWarning(for: plant, events: events, now: now, calendar: calendar)?.signature ?? "ok"
    }

    private static func allWarnings(
        for pet: Pet,
        events: [Event],
        now: Date,
        calendar: Calendar
    ) -> [CarePlanOverdueStatus] {
        let feedRules = FeedRuleState(pet: pet, allEvents: events, now: now, calendar: calendar)
        let feedMode = feedRules.operatingMode
        let hasExpiredFeedMiss = !feedRules.expiredMissedManualReminders.isEmpty
        let reminderWarnings = events.flatMap { event -> [CarePlanOverdueStatus] in
            guard event.isActionableTask,
                  eventBelongsToPet(event, pet: pet),
                  !FeedRuleMetadata.isAutoFeederEvent(event, pet: pet),
                  let actionType = planActionType(for: event),
                  let title = warningTitle(for: actionType) else {
                return []
            }

            if actionType == "feed" {
                guard feedMode == .manualReminder, !hasExpiredFeedMiss else {
                    return []
                }
            }

            return event.reminders.compactMap { reminder in
                guard reminder.isFailed || (reminder.isPending && reminder.scheduledAt < now) else {
                    return nil
                }
                if actionType == "feed", !FeedPlanCatchUpPolicy.isCatchUpEligible(reminder, now: now) {
                    return nil
                }
                return CarePlanOverdueStatus(
                    title: title,
                    actionType: actionType,
                    scheduledAt: reminder.scheduledAt,
                    daysOverdue: overdueDays(from: reminder.scheduledAt, to: now, calendar: calendar),
                    reminderId: reminder.id,
                    eventId: event.id
                )
            }
        }

        return (reminderWarnings + waterCycleWarnings(for: pet, now: now, calendar: calendar))
            .sorted {
                if $0.scheduledAt == $1.scheduledAt {
                    return $0.actionType < $1.actionType
                }
                return $0.scheduledAt < $1.scheduledAt
            }
    }

    private static func humanWarnings(
        for human: Human,
        events: [Event],
        medications: [HumanMedication],
        logs: [HumanMedicationLog],
        now: Date,
        calendar: Calendar
    ) -> [CarePlanOverdueStatus] {
        let eventWarnings = events.flatMap { event -> [CarePlanOverdueStatus] in
            guard event.isActionableTask,
                  eventBelongsToHuman(event, human: human, medications: medications),
                  let actionType = humanPlanActionType(for: event),
                  let title = humanWarningTitle(for: actionType) else {
                return []
            }

            return event.reminders.compactMap { reminder in
                guard reminder.isFailed || (reminder.isPending && reminder.scheduledAt < now) else {
                    return nil
                }
                return CarePlanOverdueStatus(
                    title: title,
                    actionType: actionType,
                    scheduledAt: reminder.scheduledAt,
                    daysOverdue: overdueDays(from: reminder.scheduledAt, to: now, calendar: calendar),
                    reminderId: reminder.id,
                    eventId: event.id
                )
            }
        }

        return (eventWarnings + humanMedicationWarnings(for: human, medications: medications, logs: logs, now: now, calendar: calendar))
            .sorted {
                if $0.scheduledAt == $1.scheduledAt {
                    return $0.actionType < $1.actionType
                }
                return $0.scheduledAt < $1.scheduledAt
            }
    }

    private static func humanMedicationWarnings(
        for human: Human,
        medications: [HumanMedication],
        logs: [HumanMedicationLog],
        now: Date,
        calendar: Calendar
    ) -> [CarePlanOverdueStatus] {
        let humanId = human.id.uuidString
        let relevantMeds = medications.filter {
            $0.humanId == humanId && $0.isActive && !$0.frequency.isManualEntry
        }
        guard !relevantMeds.isEmpty else { return [] }

        return relevantMeds.flatMap { medication -> [CarePlanOverdueStatus] in
            let scheduleWindow = humanScheduleWindow(for: medication, now: now, calendar: calendar)
            return scheduleWindow.compactMap { dose in
                guard dose.scheduledTime < now else { return nil }
                let matching = HumanMedicationLogStore.matchingLog(
                    in: logs,
                    humanId: humanId,
                    medicationId: medication.id.uuidString,
                    scheduledTime: dose.scheduledTime,
                    calendar: calendar
                )
                guard matching?.status != .taken && matching?.status != .skipped else {
                    return nil
                }
                return CarePlanOverdueStatus(
                    title: "用药",
                    actionType: "humanMedication",
                    scheduledAt: dose.scheduledTime,
                    daysOverdue: overdueDays(from: dose.scheduledTime, to: now, calendar: calendar),
                    reminderId: nil,
                    eventId: nil
                )
            }
        }
    }

    private static func plantWarnings(
        for plant: Plant,
        events: [Event],
        now: Date,
        calendar: Calendar
    ) -> [CarePlanOverdueStatus] {
        let eventWarnings = events.flatMap { event -> [CarePlanOverdueStatus] in
            guard event.isActionableTask,
                  eventBelongsToPlant(event, plant: plant),
                  let actionType = plantPlanActionType(for: event),
                  let title = plantWarningTitle(for: actionType) else {
                return []
            }

            return event.reminders.compactMap { reminder in
                guard reminder.isFailed || (reminder.isPending && reminder.scheduledAt < now) else {
                    return nil
                }
                return CarePlanOverdueStatus(
                    title: title,
                    actionType: actionType,
                    scheduledAt: reminder.scheduledAt,
                    daysOverdue: overdueDays(from: reminder.scheduledAt, to: now, calendar: calendar),
                    reminderId: reminder.id,
                    eventId: event.id
                )
            }
        }

        return (eventWarnings + plantCycleWarnings(for: plant, now: now, calendar: calendar))
            .sorted {
                if $0.scheduledAt == $1.scheduledAt {
                    return $0.actionType < $1.actionType
                }
                return $0.scheduledAt < $1.scheduledAt
            }
    }

    private static func waterCycleWarnings(
        for pet: Pet,
        now: Date,
        calendar: Calendar
    ) -> [CarePlanOverdueStatus] {
        [
            cycleWarning(
                title: "换水",
                actionType: "waterChange",
                status: WaterCareCycleStatusCalculator.waterChangeStatus(for: pet, now: now, calendar: calendar),
                now: now,
                calendar: calendar
            ),
            cycleWarning(
                title: "滤芯",
                actionType: "filterClean",
                status: WaterCareCycleStatusCalculator.filterCleanStatus(for: pet, now: now, calendar: calendar),
                now: now,
                calendar: calendar
            ),
            cycleWarning(
                title: "更换",
                actionType: "filterClean",
                status: WaterCareCycleStatusCalculator.filterReplaceStatus(for: pet, now: now, calendar: calendar),
                now: now,
                calendar: calendar
            )
        ]
        .compactMap { $0 }
    }

    private static func cycleWarning(
        title: String,
        actionType: String,
        status: WaterCareCycleStatus?,
        now: Date,
        calendar: Calendar
    ) -> CarePlanOverdueStatus? {
        guard let status, status.isOverdue else { return nil }
        let today = calendar.startOfDay(for: now)
        let scheduledAt = calendar.date(byAdding: .day, value: -max(status.overdueDays, 0), to: today) ?? today
        return CarePlanOverdueStatus(
            title: title,
            actionType: actionType,
            scheduledAt: scheduledAt,
            daysOverdue: status.overdueDays,
            reminderId: nil,
            eventId: nil
        )
    }

    private static func eventBelongsToPet(_ event: Event, pet: Pet) -> Bool {
        let petId = pet.id.uuidString
        let entityType = event.relatedEntityType.lowercased()

        if event.relatedEntityId == petId {
            return entityType.isEmpty ||
                entityType == EntityKind.pet.rawValue.lowercased() ||
                entityType == "pet" ||
                entityType.hasPrefix("pet_")
        }

        if event.eventType == EventType.petMedicationDose.rawValue ||
            entityType == PetMedicationDoseLogging.relatedEntityTypeMedication.lowercased() {
            return pet.medications.contains { $0.id.uuidString == event.relatedEntityId }
        }

        return false
    }

    private static func eventBelongsToHuman(_ event: Event, human: Human, medications: [HumanMedication]) -> Bool {
        let humanId = human.id.uuidString
        let entityType = event.relatedEntityType.lowercased()

        if event.assigneeId == humanId {
            return true
        }

        if event.relatedEntityId == humanId {
            return entityType.isEmpty ||
                entityType == EntityKind.human.rawValue.lowercased() ||
                entityType == "human" ||
                entityType.hasPrefix("human_")
        }

        if entityType == "human_medication" {
            return medications.first { $0.id.uuidString == event.relatedEntityId }?.humanId == humanId
        }

        return false
    }

    private static func eventBelongsToPlant(_ event: Event, plant: Plant) -> Bool {
        let plantId = plant.id.uuidString
        let entityType = event.relatedEntityType.lowercased()

        guard event.relatedEntityId == plantId else { return false }
        return entityType.isEmpty ||
            entityType == EntityKind.plant.rawValue.lowercased() ||
            entityType == "plant" ||
            entityType.hasPrefix("plant_")
    }

    private static func planActionType(for event: Event) -> String? {
        if event.eventType == EventType.petMedicationDose.rawValue ||
            event.relatedEntityType.lowercased() == PetMedicationDoseLogging.relatedEntityTypeMedication {
            return "medication"
        }
        if FeedRuleMetadata.isAutoFeederEvent(event, petId: event.relatedEntityId) {
            return nil
        }
        if event.feedRuleKind == .manualReminder || event.eventType == EventType.foodChange.rawValue {
            return "feed"
        }

        let text = normalizedText(for: event)
        if event.eventType == EventType.litterBox.rawValue || matchesAny(text, ["铲", "猫砂", "litter", "scoop", "toilet", "klo"]) {
            return "litter"
        }
        if matchesAny(text, ["换水", "water change", "wasserwechsel"]) {
            return "waterChange"
        }
        if matchesAny(text, ["滤", "filter"]) {
            return "filterClean"
        }
        if event.eventType == EventType.watering.rawValue || matchesAny(text, ["喂水", "喝水", "饮水", "drink", "wasser"]) {
            return "water"
        }
        if matchesAny(text, ["清笼", "鸟笼", "cage", "käfig"]) {
            return "cageCleaning"
        }
        if matchesAny(text, ["放飞", "free flight", "freiflug"]) {
            return "freeFlight"
        }
        if matchesAny(text, ["保湿", "喷水", "mist", "spray", "befeuchten"]) {
            return "misting"
        }
        if matchesAny(text, ["垫材", "substrate", "substrat"]) {
            return "substrateChange"
        }
        if event.eventType == EventType.grooming.rawValue || matchesAny(text, ["护理", "groom", "pflege", "洗", "刷", "剪", "耳", "梳"]) {
            return "groom"
        }
        if matchesAny(text, ["陪玩", "逗", "play", "spielen"]) {
            return "play"
        }
        if matchesAny(text, ["喂食", "喂", "吃", "粮", "feed", "food", "meal", "futter", "fütter"]) {
            return "feed"
        }
        if event.eventType == EventType.health.rawValue ||
            event.eventType == EventType.vaccine.rawValue ||
            event.eventType == EventType.externalDeworming.rawValue ||
            event.eventType == EventType.internalDeworming.rawValue ||
            event.eventType == EventType.vetVisit.rawValue {
            return "health"
        }
        if event.eventType == EventType.insurancePremium.rawValue {
            return "insurance"
        }

        return nil
    }

    private static func humanPlanActionType(for event: Event) -> String? {
        if event.eventType == EventType.medication.rawValue ||
            event.relatedEntityType.lowercased() == "human_medication" {
            return "humanMedication"
        }

        let text = normalizedText(for: event)
        if event.eventType == EventType.health.rawValue ||
            event.eventType == EventType.vetVisit.rawValue ||
            matchesAny(text, ["体检", "健康", "就医", "复诊", "doctor", "checkup", "health", "arzt"]) {
            return "humanHealth"
        }
        if matchesAny(text, ["吃药", "用药", "药", "medication", "medicine", "pill", "tablette"]) {
            return "humanMedication"
        }
        if matchesAny(text, ["体重", "weight", "gewicht"]) {
            return "humanWeight"
        }
        if matchesAny(text, ["运动", "健身", "workout", "exercise", "sport"]) {
            return "humanWorkout"
        }
        if matchesAny(text, ["花费", "记账", "expense", "cost", "kosten"]) {
            return "humanExpense"
        }
        if event.eventType == EventType.task.rawValue || event.eventType == EventType.chore.rawValue {
            return "humanTask"
        }

        return nil
    }

    private static func plantPlanActionType(for event: Event) -> String? {
        if event.eventType == EventType.watering.rawValue {
            return "plantWatering"
        }
        if event.eventType == EventType.fertilizing.rawValue {
            return "plantFertilizing"
        }

        let text = normalizedText(for: event)
        if matchesAny(text, ["浇水", "watering", "water", "gießen", "wasser"]) {
            return "plantWatering"
        }
        if matchesAny(text, ["施肥", "fertiliz", "fertilis", "düng"]) {
            return "plantFertilizing"
        }
        if event.eventType == EventType.task.rawValue {
            return "plantTask"
        }

        return nil
    }

    private static func warningTitle(for actionType: String) -> String? {
        switch actionType {
        case "feed": return "喂食"
        case "water": return "喂水"
        case "waterChange": return "换水"
        case "filterClean": return "滤芯"
        case "litter": return "铲屎"
        case "play": return "陪玩"
        case "groom": return "护理"
        case "medication": return "用药"
        case "health": return "健康"
        case "insurance": return "保险"
        case "cageCleaning": return "清笼"
        case "freeFlight": return "放飞"
        case "misting": return "保湿"
        case "substrateChange": return "换垫"
        default: return nil
        }
    }

    private static func humanWarningTitle(for actionType: String) -> String? {
        switch actionType {
        case "humanMedication": return "用药"
        case "humanHealth": return "健康"
        case "humanWeight": return "体重"
        case "humanWorkout": return "运动"
        case "humanExpense": return "花费"
        case "humanTask": return "任务"
        default: return nil
        }
    }

    private static func plantWarningTitle(for actionType: String) -> String? {
        switch actionType {
        case "plantWatering": return "浇水"
        case "plantFertilizing": return "施肥"
        case "plantTask": return "植物"
        default: return nil
        }
    }

    private static func humanScheduleWindow(
        for medication: HumanMedication,
        now: Date,
        calendar: Calendar
    ) -> [HumanMedicationScheduleDose] {
        let today = calendar.startOfDay(for: now)
        return (0...6)
            .compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
            .flatMap { HumanMedicationSchedulePlan.doses(on: $0, for: medication, calendar: calendar) }
            .sorted { $0.scheduledTime < $1.scheduledTime }
    }

    private static func plantCycleWarnings(
        for plant: Plant,
        now: Date,
        calendar: Calendar
    ) -> [CarePlanOverdueStatus] {
        [
            plantCycleWarning(
                title: "浇水",
                actionType: "plantWatering",
                lastCareDate: plant.lastWateredDate ?? latestPlantCareDate(for: plant, type: .watering),
                intervalDays: plant.wateringIntervalDays,
                now: now,
                calendar: calendar
            ),
            plantCycleWarning(
                title: "施肥",
                actionType: "plantFertilizing",
                lastCareDate: plant.lastFertilizedDate ?? latestPlantCareDate(for: plant, type: .fertilizing),
                intervalDays: plant.fertilizingIntervalDays,
                now: now,
                calendar: calendar
            )
        ]
        .compactMap { $0 }
    }

    private static func latestPlantCareDate(for plant: Plant, type: PlantCareType) -> Date? {
        plant.careLogs
            .filter { $0.careType == type }
            .map(\.date)
            .max()
    }

    private static func plantCycleWarning(
        title: String,
        actionType: String,
        lastCareDate: Date?,
        intervalDays: Int,
        now: Date,
        calendar: Calendar
    ) -> CarePlanOverdueStatus? {
        guard let lastCareDate else { return nil }
        let interval = max(intervalDays, 1)
        let dueDate = calendar.date(
            byAdding: .day,
            value: interval,
            to: calendar.startOfDay(for: lastCareDate)
        ) ?? calendar.startOfDay(for: lastCareDate)

        guard dueDate < calendar.startOfDay(for: now) else { return nil }
        return CarePlanOverdueStatus(
            title: title,
            actionType: actionType,
            scheduledAt: dueDate,
            daysOverdue: overdueDays(from: dueDate, to: now, calendar: calendar),
            reminderId: nil,
            eventId: nil
        )
    }

    private static func acceptedActionTypes(for quickActionType: String) -> Set<String> {
        switch quickActionType {
        case "water":
            return ["water"]
        case "filterClean":
            return ["filterClean"]
        case "health":
            return ["health", "insurance"]
        default:
            return [quickActionType]
        }
    }

    private static func overdueDays(from date: Date, to now: Date, calendar: Calendar) -> Int {
        max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0)
    }

    private static func normalizedText(for event: Event) -> String {
        "\(event.title) \(event.eventType) \(event.relatedEntityType)".lowercased()
    }

    private static func matchesAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0.lowercased()) }
    }
}

private extension FeedRuleMetadata {
    static func isAutoFeederEvent(_ event: Event, petId: String) -> Bool {
        event.relatedEntityType == autoFeederEntityType &&
            event.relatedEntityId == petId &&
            event.eventType == EventType.foodChange.rawValue
    }
}
