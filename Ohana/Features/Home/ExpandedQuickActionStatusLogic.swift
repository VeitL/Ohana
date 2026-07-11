//
//  ExpandedQuickActionStatusLogic.swift
//  Ohana
//
//  Focused status projection for expanded pet quick actions.
//

import Foundation

nonisolated struct ExpandedQuickActionStatusContext {
    let pet: Pet
    let events: [Event]
    let feedingEntries: [HomeFeedQuickActionEntry]
    let careEntries: [HomeCareQuickActionEntry]
    let hygieneEntries: [HomeHygieneQuickActionEntry]
    let walkEntries: [HomeWalkQuickActionEntry]
    let pottyEntries: [HomePottyQuickActionEntry]
    let expenseEntries: [HomePetExpenseQuickActionEntry]
    let weightEntries: [HomePetWeightQuickActionEntry]
    let momentEntries: [HomePetMomentQuickActionEntry]
    let now: Date
    let calendar: Calendar
    let localization: L10n
}

nonisolated enum ExpandedQuickActionStatusLogic {
    static func countText(actionType: String, context: ExpandedQuickActionStatusContext) -> String? {
        switch actionType {
        case "feed":
            feedText(context)
        case "water", "waterChange", "filterClean":
            waterText(actionType: actionType, context: context)
        case "walk", "potty", "litter", "play":
            routineText(actionType: actionType, context: context)
        case "weight", "medication", "expense", "moment":
            trackingText(actionType: actionType, context: context)
        case "cageCleaning", "freeFlight", "misting", "substrateChange", "groom", "health":
            specialCareText(actionType: actionType, context: context)
        default:
            nil
        }
    }

    private static func feedText(_ context: ExpandedQuickActionStatusContext) -> String? {
        let state = HomeFeedQuickActionState(
            pet: context.pet,
            allEvents: context.events,
            feedingLedgerEntries: context.feedingEntries,
            now: context.now,
            calendar: context.calendar
        )
        switch state.operatingMode {
        case .manual:
            let count = state.manualMainCount
            if count > 0 { return "手动 \(count)餐" }
            return context.pet.dailyPortionGrams > 0 ? "\(Int(context.pet.dailyPortionGrams.rounded()))g" : "待设置"
        case .manualReminder:
            if state.hasMissedManualPlan {
                return "未打卡 \(state.todayManualPlanMissedCount)餐"
            }
            if let lastExpired = state.lastExpiredManualPlanDate {
                let time = quickPlanTimeText(lastExpired, now: context.now, calendar: context.calendar)
                return context.localization.tr(
                    zh: "最后逾期 \(time)",
                    en: "Last missed \(time)",
                    de: "Zuletzt überfällig \(time)"
                )
            }
            if let overdue = overdueQuickStatusText(for: "feed", context: context) {
                return overdue
            }
            return "计划 \(state.completedTodayPlanCount)/\(state.todayManualPlanTotalCount)"
        case .autoFeeder:
            return "自动 \(state.autoMainCount)次"
        }
    }

    private static func waterText(actionType: String, context: ExpandedQuickActionStatusContext) -> String? {
        let pet = context.pet
        let waterCycleSnapshot = waterCycleLogSnapshot(for: pet, careLedgerEntries: context.careEntries)
        switch actionType {
        case "water":
            if WaterQuickActionPolicy.isAquatic(species: pet.species) {
                if let warning = WaterCareCycleStatusCalculator.mostUrgentWaterWarning(
                    for: pet,
                    now: context.now,
                    calendar: context.calendar,
                    logSnapshot: waterCycleSnapshot
                ) {
                    return waterCycleOverdueText(
                        title: warning.localizedTitle(l: context.localization),
                        days: warning.status.overdueDays,
                        l: context.localization
                    )
                }
                return aquaticWaterStatusText(context)
            }
            if let overdue = overdueQuickStatusText(for: actionType, context: context) {
                return overdue
            }
            let waterState = ExpandedQuickActionLogic.waterRuleState(for: pet, allEvents: context.events)
            if waterState.operatingMode == .reminder {
                return waterState.missedCount > 0 ? "待补 \(waterState.missedCount)次" : "计划 \(waterState.completionText)"
            }
            let count = todayCareEntryCount(.watering, context: context)
            if count > 0 { return "今日 \(count)次" }
            if let amount = ExpandedQuickActionLogic.defaultWaterAmountMl(for: pet) {
                return "\(Int(amount.rounded()))ml"
            }
            return "只记录次数"
        case "waterChange":
            if let status = WaterCareCycleStatusCalculator.waterChangeStatus(
                for: pet,
                now: context.now,
                calendar: context.calendar,
                logSnapshot: waterCycleSnapshot
            ) {
                if status.isOverdue { return status.compactDueText(l: context.localization) }
                if status.isDueToday { return context.localization.tr(zh: "今天应换", en: "Due today", de: "Heute fällig") }
            }
            if let overdue = overdueQuickStatusText(for: actionType, context: context) { return overdue }
            return latestCareAgeText(.waterChange, context: context, todayDone: "今天已换")
        case "filterClean":
            return filterStatusText(context, waterCycleSnapshot: waterCycleSnapshot)
        default:
            return nil
        }
    }

    private static func filterStatusText(
        _ context: ExpandedQuickActionStatusContext,
        waterCycleSnapshot: WaterCareCycleLogSnapshot
    ) -> String? {
        if let status = WaterCareCycleStatusCalculator.filterReplaceStatus(
            for: context.pet,
            now: context.now,
            calendar: context.calendar,
            logSnapshot: waterCycleSnapshot
        ), status.isOverdue {
            return waterCycleOverdueText(
                title: context.localization.tr(zh: "更换", en: "Replacement", de: "Wechsel"),
                days: status.overdueDays,
                l: context.localization
            )
        }
        if let status = WaterCareCycleStatusCalculator.filterCleanStatus(
            for: context.pet,
            now: context.now,
            calendar: context.calendar,
            logSnapshot: waterCycleSnapshot
        ) {
            if status.isOverdue {
                return waterCycleOverdueText(
                    title: context.localization.tr(zh: "清洗", en: "Cleaning", de: "Reinigung"),
                    days: status.overdueDays,
                    l: context.localization
                )
            }
            if status.isDueToday { return context.localization.tr(zh: "今天应清", en: "Due today", de: "Heute fällig") }
        }
        if let overdue = overdueQuickStatusText(for: "filterClean", context: context) { return overdue }
        return latestCareAgeText(.filterClean, context: context, todayDone: "今天已清")
    }

    private static func routineText(actionType: String, context: ExpandedQuickActionStatusContext) -> String? {
        switch actionType {
        case "walk":
            let walks = todayWalkEntries(context: context)
            guard !walks.isEmpty else { return "今日未遛" }
            let distance = walks.reduce(0.0) { $0 + $1.distanceMeters }
            let distanceText = distance >= 1000
                ? String(format: "%.1fkm", distance / 1000)
                : String(format: "%.0fm", distance)
            return "今日 \(walks.count)次 · \(distanceText)"
        case "potty":
            let count = todayPottyEntries(context: context).count
            if count > 0 { return "今日 \(count)次" }
            if let last = latestPottyEntry(context), last.pottyType == .softPoop || last.pottyType == .liquidPoop {
                return "最近异常"
            }
            return nil
        case "litter":
            if let overdue = overdueQuickStatusText(for: actionType, context: context) { return overdue }
            if todayCareEntryCount(.litter, context: context) > 0 { return "今日已铲" }
            return scoopQuickStatusText(context)
        case "play":
            if let overdue = overdueQuickStatusText(for: actionType, context: context) { return overdue }
            let count = todayCareEntryCount(.play, context: context)
            if count > 0 { return "今日陪玩 \(count)次" }
            if let event = ExpandedQuickActionLogic.playPlanEvent(for: context.pet, allEvents: context.events) {
                let eventDay = context.calendar.startOfDay(for: event.startDate)
                let today = context.calendar.startOfDay(for: context.now)
                return eventDay <= today ? "计划待陪" : "计划 \(relativeFutureDayText(for: event.startDate, calendar: context.calendar))"
            }
            return "今日未陪"
        default:
            return nil
        }
    }

    private static func trackingText(actionType: String, context: ExpandedQuickActionStatusContext) -> String? {
        switch actionType {
        case "weight":
            return latestWeightEntry(context).map { String(format: "%.1fkg", $0.weightKg) }
        case "medication":
            let activeMedications = context.pet.medications.filter(\.isActiveToday)
            guard !activeMedications.isEmpty else { return "待设置" }
            let planned = activeMedications.reduce(0) { $0 + PetMedicationDoseLogging.requiredDoses(on: context.now, for: $1) }
            let done = activeMedications.reduce(0) {
                $0 + PetMedicationDoseLogging.todayDoseCount(events: context.events, medicationId: $1.id)
            }
            if let overdue = overdueQuickStatusText(for: actionType, context: context) { return overdue }
            return planned > 0 ? "今日 \(min(done, planned))/\(planned)" : "\(activeMedications.count)种药"
        case "expense":
            let total = context.expenseEntries
                .filter {
                    $0.petId == context.pet.id &&
                        context.calendar.isDate($0.date, equalTo: context.now, toGranularity: .month)
                }
                .reduce(0.0) { $0 + $1.amount }
            return total > 0 ? "本月 \(AppCurrency.format(total, fractionDigits: 0))" : nil
        case "moment":
            return momentText(context)
        default:
            return nil
        }
    }

    private static func momentText(_ context: ExpandedQuickActionStatusContext) -> String {
        let todayCount = todayMomentEntries(context: context).count
        if todayCount > 0 {
            return context.localization.tr(zh: "今天 \(todayCount) 条", en: "Today \(todayCount)", de: "Heute \(todayCount)")
        }
        if let last = latestMomentEntry(context) {
            let age = momentAgeText(for: last.date, context: context)
            return context.localization.tr(zh: "最近：\(age)", en: "Last: \(age)", de: "Zuletzt: \(age)")
        }
        return context.localization.tr(zh: "还没有记录", en: "No moments yet", de: "Noch keine Momente")
    }

    private static func specialCareText(actionType: String, context: ExpandedQuickActionStatusContext) -> String? {
        if actionType == "groom" {
            if let warning = ExpandedQuickActionLogic.mostUrgentHygieneWarning(
                for: context.pet,
                hygieneLedgerEntries: context.hygieneEntries,
                now: context.now,
                calendar: context.calendar,
                includeDueToday: true
            ) {
                return "\(warning.type.localizedLabel(context.localization)) \(warning.status.compactDueText(l: context.localization))"
            }
            let count = todayHygieneEntries(context: context).count
            return count > 0
                ? context.localization.tr(zh: "今日 \(count)项", en: "Today \(count)", de: "Heute \(count)")
                : nil
        }
        if let overdue = overdueQuickStatusText(for: actionType, context: context) { return overdue }
        switch actionType {
        case "cageCleaning":
            return latestCareAgeText(.cageCleaning, context: context, todayDone: "今天已清")
        case "freeFlight":
            let count = todayCareEntryCount(.freeFlight, context: context)
            return count > 0 ? "今日 \(count)次" : nil
        case "misting":
            let count = todayCareEntryCount(.misting, context: context)
            return count > 0 ? "今日 \(count)次" : nil
        case "substrateChange":
            return latestCareAgeText(.substrateChange, context: context, todayDone: "今天已换")
        case "health":
            return nil
        default:
            return nil
        }
    }

    static func waterCycleLogSnapshot(
        for pet: Pet,
        careLedgerEntries: [HomeCareQuickActionEntry]
    ) -> WaterCareCycleLogSnapshot {
        WaterCareCycleLogSnapshot(
            latestWaterChangeDate: latestCareEntry(.waterChange, pet: pet, careLedgerEntries: careLedgerEntries)?.date,
            latestFilterCleanDate: latestCareEntry(.filterClean, pet: pet, careLedgerEntries: careLedgerEntries)?.date
        )
    }

    static func todayCareEntryCount(
        _ type: CareType,
        pet: Pet,
        careLedgerEntries: [HomeCareQuickActionEntry],
        now: Date,
        calendar: Calendar
    ) -> Int {
        careEntries(for: pet, actionTypes: [type.rawValue], careLedgerEntries: careLedgerEntries)
            .count { calendar.isDate($0.date, inSameDayAs: now) }
    }

    static func todayHygieneEntries(
        for pet: Pet,
        hygieneLedgerEntries: [HomeHygieneQuickActionEntry],
        now: Date,
        calendar: Calendar
    ) -> [HomeHygieneQuickActionEntry] {
        hygieneLedgerEntries.filter { $0.petId == pet.id && calendar.isDate($0.date, inSameDayAs: now) }
    }

    static func todayWalkEntries(
        for pet: Pet,
        walkLedgerEntries: [HomeWalkQuickActionEntry],
        now: Date,
        calendar: Calendar
    ) -> [HomeWalkQuickActionEntry] {
        walkLedgerEntries.filter { $0.petId == pet.id && calendar.isDate($0.startDate, inSameDayAs: now) }
    }

    static func todayPottyEntries(
        for pet: Pet,
        pottyLedgerEntries: [HomePottyQuickActionEntry],
        now: Date,
        calendar: Calendar
    ) -> [HomePottyQuickActionEntry] {
        pottyLedgerEntries.filter { $0.petId == pet.id && calendar.isDate($0.date, inSameDayAs: now) }
    }

    static func todayWeightEntries(
        for pet: Pet,
        weightLedgerEntries: [HomePetWeightQuickActionEntry],
        now: Date,
        calendar: Calendar
    ) -> [HomePetWeightQuickActionEntry] {
        weightLedgerEntries.filter { $0.petId == pet.id && calendar.isDate($0.date, inSameDayAs: now) }
    }

    private static func todayCareEntryCount(_ type: CareType, context: ExpandedQuickActionStatusContext) -> Int {
        todayCareEntryCount(
            type,
            pet: context.pet,
            careLedgerEntries: context.careEntries,
            now: context.now,
            calendar: context.calendar
        )
    }

    private static func latestCareEntry(
        _ type: CareType,
        pet: Pet,
        careLedgerEntries: [HomeCareQuickActionEntry]
    ) -> HomeCareQuickActionEntry? {
        careEntries(for: pet, actionTypes: [type.rawValue], careLedgerEntries: careLedgerEntries)
            .max(by: { $0.date < $1.date })
    }

    private static func careEntries(
        for pet: Pet,
        actionTypes: Set<String>,
        careLedgerEntries: [HomeCareQuickActionEntry]
    ) -> [HomeCareQuickActionEntry] {
        careLedgerEntries.filter { $0.petId == pet.id && actionTypes.contains($0.actionType) }
    }

    private static func latestCareAgeText(
        _ type: CareType,
        context: ExpandedQuickActionStatusContext,
        todayDone: String
    ) -> String? {
        guard let last = latestCareEntry(type, pet: context.pet, careLedgerEntries: context.careEntries) else { return nil }
        let days = context.calendar.dateComponents([.day], from: last.date, to: context.now).day ?? 0
        return days == 0 ? todayDone : "\(days)天前"
    }

    private static func todayHygieneEntries(context: ExpandedQuickActionStatusContext) -> [HomeHygieneQuickActionEntry] {
        todayHygieneEntries(
            for: context.pet,
            hygieneLedgerEntries: context.hygieneEntries,
            now: context.now,
            calendar: context.calendar
        )
    }

    private static func todayWalkEntries(context: ExpandedQuickActionStatusContext) -> [HomeWalkQuickActionEntry] {
        todayWalkEntries(
            for: context.pet,
            walkLedgerEntries: context.walkEntries,
            now: context.now,
            calendar: context.calendar
        )
    }

    private static func todayPottyEntries(context: ExpandedQuickActionStatusContext) -> [HomePottyQuickActionEntry] {
        todayPottyEntries(
            for: context.pet,
            pottyLedgerEntries: context.pottyEntries,
            now: context.now,
            calendar: context.calendar
        )
    }

    private static func latestPottyEntry(_ context: ExpandedQuickActionStatusContext) -> HomePottyQuickActionEntry? {
        context.pottyEntries
            .filter { $0.petId == context.pet.id }
            .max(by: { $0.date < $1.date })
    }

    private static func latestWeightEntry(_ context: ExpandedQuickActionStatusContext) -> HomePetWeightQuickActionEntry? {
        context.weightEntries
            .filter { $0.petId == context.pet.id }
            .max(by: { $0.date < $1.date })
    }

    private static func todayMomentEntries(context: ExpandedQuickActionStatusContext) -> [HomePetMomentQuickActionEntry] {
        context.momentEntries.filter {
            $0.petId == context.pet.id && context.calendar.isDate($0.date, inSameDayAs: context.now)
        }
    }

    private static func latestMomentEntry(_ context: ExpandedQuickActionStatusContext) -> HomePetMomentQuickActionEntry? {
        context.momentEntries
            .filter { $0.petId == context.pet.id }
            .max(by: { $0.date < $1.date })
    }

    private static func overdueQuickStatusText(
        for actionType: String,
        context: ExpandedQuickActionStatusContext
    ) -> String? {
        CarePlanOverdueStatusCalculator.warning(
            for: actionType,
            pet: context.pet,
            events: context.events,
            now: context.now,
            calendar: context.calendar,
            waterCycleLogSnapshot: waterCycleLogSnapshot(for: context.pet, careLedgerEntries: context.careEntries)
        )?.compactText(l: context.localization)
    }

    private static func scoopQuickStatusText(_ context: ExpandedQuickActionStatusContext) -> String? {
        let settings = LitterCareSettingsStore.snapshot(petKey: context.pet.id.uuidString, calendar: context.calendar)
        let lastScoop = latestCareEntry(.litter, pet: context.pet, careLedgerEntries: context.careEntries)?.date
        let base = context.calendar.startOfDay(for: lastScoop ?? settings.scoopAnchorDate)
        let next = context.calendar.date(byAdding: .day, value: settings.scoopIntervalDays, to: base) ?? base
        let daysUntil = context.calendar.dateComponents(
            [.day],
            from: context.calendar.startOfDay(for: context.now),
            to: context.calendar.startOfDay(for: next)
        ).day ?? 0
        if daysUntil < 0 {
            return context.localization.tr(
                zh: "逾期 \(abs(daysUntil))天",
                en: "\(abs(daysUntil))d overdue",
                de: "\(abs(daysUntil)) T. überfällig"
            )
        }
        if daysUntil == 0 { return context.localization.tr(zh: "今天应铲", en: "Due today", de: "Heute fällig") }
        return context.localization.tr(
            zh: "每\(settings.scoopIntervalDays)天",
            en: "Every \(settings.scoopIntervalDays)d",
            de: "Alle \(settings.scoopIntervalDays) T."
        )
    }

    private static func aquaticWaterStatusText(_ context: ExpandedQuickActionStatusContext) -> String {
        if let last = careEntries(
            for: context.pet,
            actionTypes: [CareType.waterChange.rawValue, CareType.filterClean.rawValue],
            careLedgerEntries: context.careEntries
        ).max(by: { $0.date < $1.date }) {
            let days = context.calendar.dateComponents([.day], from: last.date, to: context.now).day ?? 0
            if last.actionType == CareType.filterClean.rawValue {
                return days == 0 ? "今天清滤芯" : "\(days)天前滤芯"
            }
            return days == 0 ? "今天已换水" : "\(days)天前换水"
        }
        return "长按管理"
    }

    private static func waterCycleOverdueText(title: String, days: Int, l: L10n) -> String {
        let localizedTitle: String = switch title {
        case "换水": l.tr(zh: "换水", en: "Water change", de: "Wasserwechsel")
        case "滤芯": l.tr(zh: "滤芯", en: "Filter", de: "Filter")
        case "更换": l.tr(zh: "更换", en: "Replacement", de: "Wechsel")
        case "清洗": l.tr(zh: "清洗", en: "Cleaning", de: "Reinigung")
        default: title
        }
        return l.tr(
            zh: "\(localizedTitle)逾期\(days)天",
            en: "\(localizedTitle) \(days)d overdue",
            de: "\(localizedTitle) \(days) T. überfällig"
        )
    }

    private static func quickPlanTimeText(_ date: Date, now: Date, calendar: Calendar) -> String {
        calendar.isDate(date, inSameDayAs: now)
            ? date.formatted(date: .omitted, time: .shortened)
            : date.formatted(date: .abbreviated, time: .shortened)
    }

    private static func momentAgeText(for date: Date, context: ExpandedQuickActionStatusContext) -> String {
        let days = context.calendar.dateComponents(
            [.day],
            from: context.calendar.startOfDay(for: date),
            to: context.calendar.startOfDay(for: context.now)
        ).day ?? 0
        if days <= 0 { return context.localization.tr(zh: "今天", en: "today", de: "heute") }
        if days == 1 { return context.localization.tr(zh: "昨天", en: "yesterday", de: "gestern") }
        return context.localization.tr(zh: "\(days)天前", en: "\(days)d ago", de: "vor \(days) T.")
    }

    private static func relativeFutureDayText(for date: Date, calendar: Calendar) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: calendar.startOfDay(for: date)).day ?? 0
        if days <= 0 { return "今天" }
        if days == 1 { return "明天" }
        if days == 2 { return "后天" }
        return "\(days)天后"
    }
}
