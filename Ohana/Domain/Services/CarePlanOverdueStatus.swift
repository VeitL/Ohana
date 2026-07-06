//
//  CarePlanOverdueStatus.swift
//  Ohana
//
//  Shared overdue-plan detection for pet care surfaces.
//

import Foundation

nonisolated struct CarePlanOverdueStatus: Equatable {
    let title: String
    let actionType: String
    let scheduledAt: Date
    let daysOverdue: Int
    let reminderId: UUID?
    let eventId: UUID?

    var compactText: String {
        compactText(l: .current)
    }

    func compactText(l: L10n = .current) -> String {
        daysOverdue > 0
            ? l.tr(zh: "逾期\(daysOverdue)天", en: "\(daysOverdue)d overdue", de: "\(daysOverdue) T. überfällig")
            : l.tr(zh: "逾期", en: "Overdue", de: "Überfällig")
    }

    func localizedTitle(l: L10n = .current) -> String {
        CarePlanOverdueStatusCopy.title(for: actionType, fallback: title, l: l)
    }

    func localizedOverdueText(l: L10n = .current) -> String {
        let localizedTitle = localizedTitle(l: l)
        return daysOverdue > 0
            ? l.tr(
                zh: "\(localizedTitle)逾期\(daysOverdue)天",
                en: "\(localizedTitle) \(daysOverdue)d overdue",
                de: "\(localizedTitle) \(daysOverdue) T. überfällig"
            )
            : l.tr(
                zh: "\(localizedTitle)逾期",
                en: "\(localizedTitle) overdue",
                de: "\(localizedTitle) überfällig"
            )
    }

    var signature: String {
        let reminder = reminderId?.uuidString ?? "cycle"
        let event = eventId?.uuidString ?? "cycle"
        return "\(actionType):\(reminder):\(event):\(Int(scheduledAt.timeIntervalSince1970)):\(daysOverdue)"
    }
}

private nonisolated enum CarePlanOverdueStatusCopy {
    static func title(for actionType: String, fallback: String, l: L10n) -> String {
        switch actionType {
        case "feed":
            l.tr(zh: "喂食", en: "Feeding", de: "Fütterung")
        case "water":
            l.tr(zh: "喂水", en: "Water", de: "Wasser")
        case "waterChange":
            l.tr(zh: "换水", en: "Water change", de: "Wasserwechsel")
        case "filterClean":
            l.tr(zh: "滤芯", en: "Filter", de: "Filter")
        case "litter":
            l.tr(zh: "铲屎", en: "Scoop", de: "Klo")
        case "play":
            l.tr(zh: "陪玩", en: "Play", de: "Spielen")
        case "groom":
            l.tr(zh: "护理", en: "Care", de: "Pflege")
        case "medication", "humanMedication":
            l.tr(zh: "用药", en: "Medication", de: "Medikament")
        case "health", "humanHealth":
            l.tr(zh: "健康", en: "Health", de: "Gesundheit")
        case "insurance":
            l.tr(zh: "保险", en: "Insurance", de: "Versicherung")
        case "cageCleaning":
            l.tr(zh: "清笼", en: "Cage cleaning", de: "Käfigreinigung")
        case "freeFlight":
            l.tr(zh: "放飞", en: "Free flight", de: "Freiflug")
        case "misting":
            l.tr(zh: "保湿", en: "Misting", de: "Befeuchten")
        case "substrateChange":
            l.tr(zh: "换垫", en: "Substrate", de: "Substrat")
        case "humanWeight":
            l.tr(zh: "体重", en: "Weight", de: "Gewicht")
        case "humanWorkout":
            l.tr(zh: "运动", en: "Workout", de: "Training")
        case "humanExpense":
            l.tr(zh: "花费", en: "Expense", de: "Ausgabe")
        case "humanTask":
            l.tr(zh: "任务", en: "Task", de: "Aufgabe")
        case "plantWatering":
            l.tr(zh: "浇水", en: "Watering", de: "Gießen")
        case "plantFertilizing":
            l.tr(zh: "施肥", en: "Fertilizing", de: "Düngen")
        case "plantTask":
            l.tr(zh: "植物", en: "Plant", de: "Pflanze")
        default:
            fallback
        }
    }
}

nonisolated enum CarePlanOverdueStatusCalculator {
    static func petWarning(
        for pet: Pet,
        events: [Event],
        now: Date = Date(),
        calendar: Calendar = .current,
        waterCycleLogSnapshot: WaterCareCycleLogSnapshot? = nil
    ) -> CarePlanOverdueStatus? {
        allWarnings(
            for: pet,
            events: events,
            now: now,
            calendar: calendar,
            waterCycleLogSnapshot: waterCycleLogSnapshot
        ).first
    }

    static func petWarningCount(
        for pet: Pet,
        events: [Event],
        now: Date = Date(),
        calendar: Calendar = .current,
        waterCycleLogSnapshot: WaterCareCycleLogSnapshot? = nil
    ) -> Int {
        allWarnings(
            for: pet,
            events: events,
            now: now,
            calendar: calendar,
            waterCycleLogSnapshot: waterCycleLogSnapshot
        ).count
    }

    static func warning(
        for actionType: String,
        pet: Pet,
        events: [Event],
        now: Date = Date(),
        calendar: Calendar = .current,
        waterCycleLogSnapshot: WaterCareCycleLogSnapshot? = nil
    ) -> CarePlanOverdueStatus? {
        let accepted = acceptedActionTypes(for: actionType)
        return allWarnings(
            for: pet,
            events: events,
            now: now,
            calendar: calendar,
            waterCycleLogSnapshot: waterCycleLogSnapshot
        )
            .first { accepted.contains($0.actionType) }
    }

    static func petDueTodayCount(
        for actionType: String? = nil,
        pet: Pet,
        events: [Event],
        now: Date = Date(),
        calendar: Calendar = .current,
        waterCycleLogSnapshot: WaterCareCycleLogSnapshot? = nil
    ) -> Int {
        let accepted = actionType.map(acceptedActionTypes(for:))
        return petDueTodayStatuses(
            for: pet,
            events: events,
            now: now,
            calendar: calendar,
            waterCycleLogSnapshot: waterCycleLogSnapshot
        )
        .count(where: { status in
            accepted.map { $0.contains(status.actionType) } ?? true
        })
    }

    static func homeSignature(
        for pet: Pet,
        events: [Event],
        now: Date = Date(),
        calendar: Calendar = .current,
        waterCycleLogSnapshot: WaterCareCycleLogSnapshot? = nil
    ) -> String {
        petWarning(
            for: pet,
            events: events,
            now: now,
            calendar: calendar,
            waterCycleLogSnapshot: waterCycleLogSnapshot
        )?.signature ?? "ok"
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

    static func humanWarningCount(
        for human: Human,
        events: [Event],
        medications: [HumanMedication],
        logs: [HumanMedicationLog],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        humanWarnings(
            for: human,
            events: events,
            medications: medications,
            logs: logs,
            now: now,
            calendar: calendar
        ).count
    }

    static func humanWarningCount(
        matching actionType: String,
        for human: Human,
        events: [Event],
        medications: [HumanMedication],
        logs: [HumanMedicationLog],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        humanWarnings(
            for: human,
            events: events,
            medications: medications,
            logs: logs,
            now: now,
            calendar: calendar
        )
        .count { $0.actionType == actionType }
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

    static func humanDueTodayCount(
        for actionType: String? = nil,
        human: Human,
        events: [Event],
        medications: [HumanMedication],
        logs: [HumanMedicationLog],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        let accepted = actionType.map { Set([$0]) }
        return humanDueTodayStatuses(
            for: human,
            events: events,
            medications: medications,
            logs: logs,
            now: now,
            calendar: calendar
        )
        .count(where: { status in
            accepted.map { $0.contains(status.actionType) } ?? true
        })
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
        calendar: Calendar,
        waterCycleLogSnapshot: WaterCareCycleLogSnapshot? = nil
    ) -> [CarePlanOverdueStatus] {
        let feedRules = FeedRuleState(pet: pet, allEvents: events, now: now, calendar: calendar)
        let feedMode = feedRules.operatingMode
        let hasExpiredFeedMiss = !feedRules.expiredMissedManualReminders.isEmpty
        let reminderWarnings = events.flatMap { event -> [CarePlanOverdueStatus] in
            guard event.isActionableTask,
                  MemberLifecycleActiveScheduleResolver.eventBelongsToPet(
                      event,
                      petId: pet.id.uuidString,
                      petMedications: pet.medications,
                      insurances: pet.insurances
                  ),
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

        return (reminderWarnings + waterCycleWarnings(
            for: pet,
            now: now,
            calendar: calendar,
            logSnapshot: waterCycleLogSnapshot
        ))
            .sorted {
                if $0.scheduledAt == $1.scheduledAt {
                    return $0.actionType < $1.actionType
                }
                return $0.scheduledAt < $1.scheduledAt
            }
    }

    private static func petDueTodayStatuses(
        for pet: Pet,
        events: [Event],
        now: Date,
        calendar: Calendar,
        waterCycleLogSnapshot: WaterCareCycleLogSnapshot? = nil
    ) -> [CarePlanOverdueStatus] {
        let feedRules = FeedRuleState(pet: pet, allEvents: events, now: now, calendar: calendar)
        let reminderStatuses = events.flatMap { event -> [CarePlanOverdueStatus] in
            guard event.isActionableTask,
                  MemberLifecycleActiveScheduleResolver.eventBelongsToPet(
                      event,
                      petId: pet.id.uuidString,
                      petMedications: pet.medications,
                      insurances: pet.insurances
                  ),
                  !FeedRuleMetadata.isAutoFeederEvent(event, pet: pet),
                  let actionType = planActionType(for: event),
                  let title = warningTitle(for: actionType) else {
                return []
            }

            if actionType == "feed", feedRules.operatingMode != .manualReminder {
                return []
            }

            return event.reminders.compactMap { reminder in
                guard reminder.isPending,
                      reminder.scheduledAt >= now,
                      calendar.isDate(reminder.scheduledAt, inSameDayAs: now) else {
                    return nil
                }
                return CarePlanOverdueStatus(
                    title: title,
                    actionType: actionType,
                    scheduledAt: reminder.scheduledAt,
                    daysOverdue: 0,
                    reminderId: reminder.id,
                    eventId: event.id
                )
            }
        }

        return (reminderStatuses + waterCycleDueTodayStatuses(
            for: pet,
            now: now,
            calendar: calendar,
            logSnapshot: waterCycleLogSnapshot
        ))
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
                  MemberLifecycleActiveScheduleResolver.eventBelongsToHuman(
                      event,
                      humanId: human.id.uuidString,
                      humanMedications: medications
                  ),
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

    private static func humanDueTodayStatuses(
        for human: Human,
        events: [Event],
        medications: [HumanMedication],
        logs: [HumanMedicationLog],
        now: Date,
        calendar: Calendar
    ) -> [CarePlanOverdueStatus] {
        let eventStatuses = events.flatMap { event -> [CarePlanOverdueStatus] in
            guard event.isActionableTask,
                  MemberLifecycleActiveScheduleResolver.eventBelongsToHuman(
                      event,
                      humanId: human.id.uuidString,
                      humanMedications: medications
                  ),
                  let actionType = humanPlanActionType(for: event),
                  let title = humanWarningTitle(for: actionType) else {
                return []
            }

            return event.reminders.compactMap { reminder in
                guard reminder.isPending,
                      reminder.scheduledAt >= now,
                      calendar.isDate(reminder.scheduledAt, inSameDayAs: now) else {
                    return nil
                }
                return CarePlanOverdueStatus(
                    title: title,
                    actionType: actionType,
                    scheduledAt: reminder.scheduledAt,
                    daysOverdue: 0,
                    reminderId: reminder.id,
                    eventId: event.id
                )
            }
        }

        return (eventStatuses + humanMedicationDueTodayStatuses(for: human, medications: medications, logs: logs, now: now, calendar: calendar))
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
                guard matching?.status != .taken, matching?.status != .skipped else {
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

    private static func humanMedicationDueTodayStatuses(
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
            HumanMedicationSchedulePlan.doses(on: now, for: medication, calendar: calendar).compactMap { dose in
                guard dose.scheduledTime >= now,
                      calendar.isDate(dose.scheduledTime, inSameDayAs: now) else {
                    return nil
                }
                let matching = HumanMedicationLogStore.matchingLog(
                    in: logs,
                    humanId: humanId,
                    medicationId: medication.id.uuidString,
                    scheduledTime: dose.scheduledTime,
                    calendar: calendar
                )
                guard matching?.status != .taken, matching?.status != .skipped else {
                    return nil
                }
                return CarePlanOverdueStatus(
                    title: "用药",
                    actionType: "humanMedication",
                    scheduledAt: dose.scheduledTime,
                    daysOverdue: 0,
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
        calendar: Calendar,
        logSnapshot: WaterCareCycleLogSnapshot? = nil
    ) -> [CarePlanOverdueStatus] {
        [
            cycleWarning(
                title: "换水",
                actionType: "waterChange",
                status: WaterCareCycleStatusCalculator.waterChangeStatus(
                    for: pet,
                    now: now,
                    calendar: calendar,
                    logSnapshot: logSnapshot
                ),
                now: now,
                calendar: calendar
            ),
            cycleWarning(
                title: "滤芯",
                actionType: "filterClean",
                status: WaterCareCycleStatusCalculator.filterCleanStatus(
                    for: pet,
                    now: now,
                    calendar: calendar,
                    logSnapshot: logSnapshot
                ),
                now: now,
                calendar: calendar
            ),
            cycleWarning(
                title: "更换",
                actionType: "filterClean",
                status: WaterCareCycleStatusCalculator.filterReplaceStatus(
                    for: pet,
                    now: now,
                    calendar: calendar,
                    logSnapshot: logSnapshot
                ),
                now: now,
                calendar: calendar
            )
        ]
        .compactMap(\.self)
    }

    private static func waterCycleDueTodayStatuses(
        for pet: Pet,
        now: Date,
        calendar: Calendar,
        logSnapshot: WaterCareCycleLogSnapshot? = nil
    ) -> [CarePlanOverdueStatus] {
        [
            cycleDueTodayStatus(
                title: "换水",
                actionType: "waterChange",
                status: WaterCareCycleStatusCalculator.waterChangeStatus(
                    for: pet,
                    now: now,
                    calendar: calendar,
                    logSnapshot: logSnapshot
                ),
                now: now,
                calendar: calendar
            ),
            cycleDueTodayStatus(
                title: "滤芯",
                actionType: "filterClean",
                status: WaterCareCycleStatusCalculator.filterCleanStatus(
                    for: pet,
                    now: now,
                    calendar: calendar,
                    logSnapshot: logSnapshot
                ),
                now: now,
                calendar: calendar
            ),
            cycleDueTodayStatus(
                title: "更换",
                actionType: "filterClean",
                status: WaterCareCycleStatusCalculator.filterReplaceStatus(
                    for: pet,
                    now: now,
                    calendar: calendar,
                    logSnapshot: logSnapshot
                ),
                now: now,
                calendar: calendar
            )
        ]
        .compactMap(\.self)
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

    private static func cycleDueTodayStatus(
        title: String,
        actionType: String,
        status: WaterCareCycleStatus?,
        now: Date,
        calendar: Calendar
    ) -> CarePlanOverdueStatus? {
        guard let status, status.isDueToday else { return nil }
        return CarePlanOverdueStatus(
            title: title,
            actionType: actionType,
            scheduledAt: calendar.startOfDay(for: now),
            daysOverdue: 0,
            reminderId: nil,
            eventId: nil
        )
    }

    private static func eventBelongsToPlant(_ event: Event, plant: Plant) -> Bool {
        let link = DomainEntityLink(event: event)
        guard DomainEntityLinkRegistry.plantId(for: link) == plant.id else { return false }
        return linkRole(for: event).isPlantScoped || DomainEntityLinkRegistry.role(for: link) == .unscoped
    }

    private static func planActionType(for event: Event) -> String? {
        let role = linkRole(for: event)
        if event.eventType == EventType.petMedication.rawValue ||
            event.eventType == EventType.petMedicationDose.rawValue ||
            role == .petMedicationPlan ||
            role == .petMedicationDose {
            return "medication"
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
        if event.eventType == EventType.insurancePremium.rawValue || role == .petInsurance {
            return "insurance"
        }

        return nil
    }

    private static func humanPlanActionType(for event: Event) -> String? {
        let role = linkRole(for: event)
        if event.eventType == EventType.medication.rawValue ||
            role == .humanMedicationPlan {
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
        case "feed": "喂食"
        case "water": "喂水"
        case "waterChange": "换水"
        case "filterClean": "滤芯"
        case "litter": "铲屎"
        case "play": "陪玩"
        case "groom": "护理"
        case "medication": "用药"
        case "health": "健康"
        case "insurance": "保险"
        case "cageCleaning": "清笼"
        case "freeFlight": "放飞"
        case "misting": "保湿"
        case "substrateChange": "换垫"
        default: nil
        }
    }

    private static func humanWarningTitle(for actionType: String) -> String? {
        switch actionType {
        case "humanMedication": "用药"
        case "humanHealth": "健康"
        case "humanWeight": "体重"
        case "humanWorkout": "运动"
        case "humanExpense": "花费"
        case "humanTask": "任务"
        default: nil
        }
    }

    private static func plantWarningTitle(for actionType: String) -> String? {
        switch actionType {
        case "plantWatering": L10n.current.tr(zh: "浇水", en: "Watering", de: "Gießen")
        case "plantFertilizing": L10n.current.tr(zh: "施肥", en: "Fertilizing", de: "Düngen")
        case "plantTask": L10n.current.tr(zh: "植物", en: "Plant", de: "Pflanze")
        default: nil
        }
    }

    private static func humanScheduleWindow(
        for medication: HumanMedication,
        now: Date,
        calendar: Calendar
    ) -> [HumanMedicationScheduleDose] {
        let today = calendar.startOfDay(for: now)
        return (0 ... 6)
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
                title: L10n.current.tr(zh: "浇水", en: "Watering", de: "Gießen"),
                actionType: "plantWatering",
                lastCareDate: plant.lastWateredDate ?? latestPlantCareDate(for: plant, type: .watering),
                intervalDays: plant.wateringIntervalDays,
                now: now,
                calendar: calendar
            ),
            plantCycleWarning(
                title: L10n.current.tr(zh: "施肥", en: "Fertilizing", de: "Düngen"),
                actionType: "plantFertilizing",
                lastCareDate: plant.lastFertilizedDate ?? latestPlantCareDate(for: plant, type: .fertilizing),
                intervalDays: plant.fertilizingIntervalDays,
                now: now,
                calendar: calendar
            )
        ]
        .compactMap(\.self)
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
            ["water"]
        case "filterClean":
            ["filterClean"]
        case "health":
            ["health", "insurance"]
        default:
            [quickActionType]
        }
    }

    private static func overdueDays(from date: Date, to now: Date, calendar: Calendar) -> Int {
        max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0)
    }

    private static func normalizedText(for event: Event) -> String {
        "\(event.title) \(event.eventType)".lowercased()
    }

    private static func linkRole(for event: Event) -> DomainEntityLinkRole {
        DomainEntityLinkRegistry.role(for: event)
    }

    private static func matchesAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0.lowercased()) }
    }
}
